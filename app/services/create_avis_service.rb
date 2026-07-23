# frozen_string_literal: true

class CreateAvisService
  class << self
    def call(claimant:, batch:, avis:, emails:, avis_source: nil)
      dossier = avis.dossier
      confidentiel = avis_source&.confidentiel || avis.confidentiel || false
      introduction_file_change = avis.attachment_changes["introduction_file"]
      introduction_file = introduction_file_change.attachable if introduction_file_change.is_a?(ActiveStorage::Attached::Changes::CreateOne)

      if claimant.is_a?(Instructeur) &&
          !claimant.follows.exists?(dossier:)
        claimant.follow(dossier)
      end

      emails, restricted_emails = filter_restricted_emails(dossier.procedure, emails)

      # create experts — batch-find existing users by email to avoid N+1
      existing_users_by_email = User.where(email: emails).index_by(&:email)
      users = []
      invalids = []
      emails.each do |email|
        user = existing_users_by_email[email]
        if user.nil?
          user = User.create_or_promote_to_expert(email, SecureRandom.hex)
        elsif user.valid? && user.expert.nil?
          user.create_expert!
        end
        (user.valid? ? users : invalids) << user
      end
      failed_emails = invalids.map { { email: it.email, messages: it.errors.full_messages } }
      failed_emails += restricted_emails.map { { email: it, messages: [I18n.t('create_avis_service.errors.expert_not_allowed')] } }

      # list all related dossiers
      dossiers = avis.invite_linked_dossiers.present? ? [dossier, *dossier.linked_dossiers_for(claimant)] : [dossier]

      # create expert <-> procedure — batch-load experts and ExpertsProcedure records
      experts = User.where(id: users.map(&:id)).includes(:expert).map(&:expert)
      procedures = dossiers.map(&:procedure).uniq

      existing_eps = ExpertsProcedure.where(procedure_id: procedures.map(&:id), expert_id: experts.map(&:id))
        .index_by { |ep| [ep.expert_id, ep.procedure_id] }

      experts_procedures_h = {}
      procedures.each do |procedure|
        experts.each do |expert|
          key = [expert, procedure]
          ep = existing_eps[[expert.id, procedure.id]]
          ep ||= ExpertsProcedure.find_or_create_by(procedure:, expert:)
          experts_procedures_h[key] = ep
        end
      end

      # create avis on all related dossiers
      persisted, failed = experts.flat_map do |expert|
        dossiers.map do |dossier|
          {
            introduction: avis.introduction,
            introduction_file:,
            claimant:,
            dossier:,
            confidentiel:,
            experts_procedure: experts_procedures_h[[expert, dossier.procedure]],
            question_label: avis.question_label,
          }
        end
      end
        .map { |params| Avis.create(params) }
        .partition(&:persisted?)

      failed_emails += failed.map { |avis| { email: avis.expert.email, messages: avis.errors.full_messages } }

      # notifications
      if persisted.any?
        dossier.touch(:last_avis_updated_at)

        if claimant.is_a?(Instructeur)
          follow = claimant.follows.find_by(dossier:)
          follow&.update_column(:avis_seen_at, Time.current)

          DossierNotification.create_notification(dossier, :attente_avis)
          claimant.mark_tab_as_seen(dossier, :avis)
        end
      end

      dossier.avis.reload

      # log operation
      persisted.each { |avis| avis.dossier.demander_un_avis!(avis) }

      persisted.each { it.dossier.emit_webhook_event(:avis_cree) }

      sent_emails = persisted.filter { it.dossier == dossier }.map do |avis|
        if avis.experts_procedure.notify_on_new_avis? && !batch
          avis.expert.user.invite_expert_and_send_avis!(avis)
        end
        avis.expert.email
      end

      [sent_emails.uniq, failed_emails]
    end

    private

    def filter_restricted_emails(procedure, emails)
      return [emails, []] if !procedure.experts_require_administrateur_invitation?

      allowed = Expert.autocomplete_mails(procedure).to_set
      emails.partition { allowed.include?(it) }
    end
  end
end
