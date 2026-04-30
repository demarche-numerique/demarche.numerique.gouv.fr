# frozen_string_literal: true

class CreateAvisService
  Result = Data.define(:avis, :sent_emails, :failed_avis)

  def self.call(dossier:, instructeur_or_expert:, batch:, params:, avis_source: nil)
    new(dossier, instructeur_or_expert, batch, params, avis_source).call
  end

  def initialize(dossier, instructeur_or_expert, batch, params, avis_source = nil)
    @dossier = dossier
    @instructeur_or_expert = instructeur_or_expert
    @batch = batch
    @params = params
    @avis_source = avis_source
  end

  def call
    if @params[:emails].blank? || @params[:emails].all?(&:blank?)
      avis = Avis.new(@params)
      avis.errors.add(:email, :blank)
      return Result.new(avis, [], [avis])
    end

    confidentiel = @avis_source&.confidentiel || @params[:confidentiel] || false

    emails = Array(@params[:emails]).map(&:strip).map(&:downcase).compact_blank
    allowed_dossiers = [@dossier]

    if @params[:invite_linked_dossiers].present?
      allowed_dossiers += @dossier.linked_dossiers_for(@instructeur_or_expert)
    end

    if @instructeur_or_expert.is_a?(Instructeur) &&
       !@instructeur_or_expert.follows.exists?(dossier: @dossier)
      @instructeur_or_expert.follow(@dossier)
    end

    sent_emails = []

    create_results = Avis.create(
      emails.flat_map do |email|
        user = User.create_or_promote_to_expert(email, SecureRandom.hex)
        allowed_dossiers.map do |dossier|
          experts_procedure = if user.valid?
            begin
              ExpertsProcedure.find_or_create_by(procedure: dossier.procedure, expert: user.expert)
            rescue ActiveRecord::RecordNotUnique
              ExpertsProcedure.find_by!(procedure: dossier.procedure, expert: user.expert)
            end
          end

          {
            email: email,
            introduction: @params[:introduction],
            introduction_file: @params[:introduction_file],
            claimant: @instructeur_or_expert,
            dossier: dossier,
            confidentiel: confidentiel,
            experts_procedure: experts_procedure,
            question_label: @params[:question_label],
          }
        end
      end
    )

    persisted, failed = create_results.partition(&:persisted?)

    if persisted.any?
      @dossier.touch(:last_avis_updated_at)

      if @instructeur_or_expert.is_a?(Instructeur)
        follow = @instructeur_or_expert.follows.find_by(dossier: @dossier)
        follow&.update_column(:avis_seen_at, Time.current)

        DossierNotification.create_notification(@dossier, :attente_avis)
        @instructeur_or_expert.mark_tab_as_seen(@dossier, :avis)
      end
    end

    @dossier.avis.reload

    persisted.each do |avis|
      avis.dossier.demander_un_avis!(avis)
      if avis.dossier == @dossier
        if avis.experts_procedure.notify_on_new_avis? && !@batch
          avis.expert.user.invite_expert_and_send_avis!(avis)
        end
        sent_emails << avis.expert.email
        avis.update_column(:email, nil)
      end
    end

    avis_result = persisted.first || failed.first || Avis.new(@params)

    Result.new(avis_result, sent_emails.uniq, failed)
  end
end
