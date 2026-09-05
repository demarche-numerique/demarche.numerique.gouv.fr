# frozen_string_literal: true

module DossierStateConcern
  extend ActiveSupport::Concern

  def usager_submit_en_construction!
    checkpoint = merge_user_buffer_stream!
    self.traitements.usager_submit_en_construction(checkpoint:)
    self.submitted_revision_id = revision_id
    save!

    # Before routing/resolve/process: those may re-route the dossier or
    # auto-transition it, and the events they emit (groupe_instructeur_change,
    # state changes) must sequence after the modification that caused them.
    emit_webhook_event(:dossier_modifie)

    RoutingEngine.compute(self)

    resolve_pending_correction!
    process_sva_svr!
    clean_champs_after_submit!
    render_carte_champs_later!
    DossierNotification.create_notification(self, :dossier_modifie)
  end

  # No dossier_modifie emission here, on purpose: instructeur edits concern
  # private champs and must not be announced as a modification of the dossier.
  # The commentaire created below does emit message_cree — also on purpose:
  # it is a genuine messagerie message, visible to the usager.
  def instructeur_submit_en_construction!(instructeur:, motivation: nil)
    checkpoint = merge_instructeur_buffer_stream!
    traitement = self.traitements.instructeur_submit_en_construction(instructeur:, checkpoint:, motivation:)
    save!

    RoutingEngine.compute(self)
    render_carte_champs_later!
    Message::DossierModifierParInstructeurComponent.create_commentaire(traitement)
  end

  def after_passer_en_construction
    self.conservation_extension = 0.days
    self.depose_at = self.en_construction_at = self.traitements
      .passer_en_construction
      .processed_at
    self.expired_at = expiration_date
    self.submitted_revision_id = revision_id

    save!

    RoutingEngine.compute(self)

    EmailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:en_construction))
    procedure.compute_dossiers_count

    # Before process_*: a declarative/sva auto-transition emits its own event,
    # which must sequence after the dépôt that caused it.
    emit_webhook_event(:dossier_depose)

    process_declarative!
    process_sva_svr!

    debounce_index_search_terms_flag.remove
    index_search_terms_later
  end

  def after_commit_passer_en_construction
    NotificationMailer.send_en_construction_notification(self).deliver_later
    NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
    enqueue_ami_notification
    groupe_instructeur.instructeurs.with_instant_email_new_dossier(self.procedure).each do |instructeur|
      DossierMailer.notify_new_dossier_depose_to_instructeur(self, instructeur.email).deliver_later
    end
    DossierNotification.create_notification(self, :dossier_depose) if !procedure.declarative? && !procedure.sva_svr_enabled?

    clean_champs_after_submit!
    render_carte_champs_later!
  end

  # The static image of a carte champ only serves the PDF exports, which only
  # concern submitted dossiers: we render at the moments the geometry becomes
  # official, never while the usager is drawing. The job short-circuits on its
  # own when the map has not moved since the last render.
  #
  # A champ that has lost its geometry still gets a job, which purges the image
  # instead of rendering one: a submission that removes the last geo area must
  # not leave the previous map behind. Only a champ with neither geometry nor
  # image is skipped, as there is nothing to do for it.
  def render_carte_champs_later!
    champ_data
      .where(type: Champs::CarteChamp.to_s, stream: Dossier::MAIN_STREAM)
      .includes(:static_map_attachment)
      .find_each { RenderCarteChampJob.enqueue_for(it) if it.geometry? || it.static_map.attached? }
  end

  def after_passer_en_instruction(h)
    instructeur = h[:instructeur]
    instructeur.follow(self)

    self.conservation_extension = 0.days
    self.en_instruction_at = self.traitements
      .passer_en_instruction(instructeur: instructeur)
      .processed_at
    self.expired_at = expiration_date

    save!

    reset_user_buffer_stream!
    reset_instructeur_buffer_stream!
    with_champs

    EmailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:en_instruction))
    resolve_pending_correction!

    log_dossier_operation(instructeur, :passer_en_instruction)
    emit_webhook_event(:dossier_en_instruction)
  end

  def after_commit_passer_en_instruction(h)
    disable_notification = h.fetch(:disable_notification, false)

    if !disable_notification
      NotificationMailer.send_en_instruction_notification(self).deliver_later
      NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
      enqueue_ami_notification
    end

    DossierNotification.destroy_notifications_by_dossier_and_type(self, :dossier_expirant)
  end

  def after_passer_automatiquement_en_instruction
    self.conservation_extension = 0.days
    self.en_instruction_at = traitements.passer_en_instruction.processed_at
    self.expired_at = expiration_date

    if procedure.declarative_en_instruction?
      self.declarative_triggered_at = en_instruction_at
    end

    save!

    EmailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:en_instruction))

    if procedure.sva_svr_enabled?
      log_automatic_dossier_operation(:passer_en_instruction, self)
    else
      log_automatic_dossier_operation(:passer_en_instruction)
    end

    emit_webhook_event(:dossier_en_instruction)
  end

  def after_commit_passer_automatiquement_en_instruction
    NotificationMailer.send_en_instruction_notification(self).deliver_later
    NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
    enqueue_ami_notification
    DossierNotification.destroy_notifications_by_dossier_and_type(self, :dossier_depose)
  end

  def after_repasser_en_construction(h)
    instructeur = h[:instructeur]

    create_missing_traitemets

    self.conservation_extension = 0.days
    self.en_construction_at = self.traitements
      .passer_en_construction(instructeur: instructeur)
      .processed_at
    self.expired_at = expiration_date

    save!

    log_dossier_operation(instructeur, :repasser_en_construction)
    emit_webhook_event(:dossier_repasse_en_construction)
  end

  def after_commit_repasser_en_construction
    enqueue_ami_notification
  end

  def after_accepter(h)
    instructeur = h[:instructeur]
    motivation = h[:motivation]
    justificatif = h[:justificatif]

    self.processed_at = self.traitements
      .accepter(motivation: motivation, instructeur: instructeur)
      .processed_at
    self.expired_at = expiration_date

    save!

    if justificatif
      self.justificatif_motivation.attach(justificatif)
    end

    save!

    EmailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:accepte))

    log_dossier_operation(instructeur, :accepter, self)
    emit_webhook_event(:dossier_accepte)
  end

  def after_commit_accepter(h)
    enqueue_attestation_generation

    disable_notification = h.fetch(:disable_notification, false)

    if !disable_notification
      if procedure.accuse_lecture?
        NotificationMailer.send_accuse_lecture_notification(self).deliver_later
      else
        NotificationMailer.send_accepte_notification(self).deliver_later
      end
      NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
      enqueue_ami_notification
    end

    send_dossier_decision_to_experts(self)
    clean_champs_after_instruction!
    remove_attente_avis_notification
  end

  def after_accepter_automatiquement
    self.processed_at = traitements.accepter_automatiquement.processed_at
    self.expired_at = expiration_date

    if procedure.declarative_accepte?
      self.en_instruction_at = self.processed_at
      self.declarative_triggered_at = self.processed_at
    elsif procedure.sva?
      self.sva_svr_decision_triggered_at = self.processed_at
    end

    save!

    EmailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:accepte))

    log_automatic_dossier_operation(:accepter, self)
    emit_webhook_event(:dossier_accepte)
  end

  def after_commit_accepter_automatiquement
    enqueue_attestation_generation

    if procedure.accuse_lecture?
      NotificationMailer.send_accuse_lecture_notification(self).deliver_later
    else
      NotificationMailer.send_accepte_notification(self).deliver_later
    end
    NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
    enqueue_ami_notification

    send_dossier_decision_to_experts(self)
    clean_champs_after_instruction!
  end

  def after_refuser(h)
    instructeur = h[:instructeur]
    motivation = h[:motivation]
    justificatif = h[:justificatif]

    self.processed_at = self.traitements
      .refuser(motivation: motivation, instructeur: instructeur)
      .processed_at
    self.expired_at = expiration_date

    save!

    if justificatif
      self.justificatif_motivation.attach(justificatif)
    end

    save!

    EmailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:refuse))

    log_dossier_operation(instructeur, :refuser, self)
    emit_webhook_event(:dossier_refuse)
  end

  def after_commit_refuser(h)
    enqueue_attestation_generation

    disable_notification = h.fetch(:disable_notification, false)

    if !disable_notification
      if procedure.accuse_lecture?
        NotificationMailer.send_accuse_lecture_notification(self).deliver_later
      else
        NotificationMailer.send_refuse_notification(self).deliver_later
      end
      NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
      enqueue_ami_notification
    end

    send_dossier_decision_to_experts(self)
    clean_champs_after_instruction!
    remove_attente_avis_notification
  end

  def after_refuser_automatiquement
    # Only SVR can refuse automatically
    I18n.with_locale(user.locale || I18n.default_locale) do
      self.motivation = I18n.t("shared.dossiers.motivation.refused_by_svr")
    end

    self.processed_at = traitements.refuser_automatiquement(motivation:).processed_at
    self.sva_svr_decision_triggered_at = self.processed_at
    self.expired_at = expiration_date

    save!

    EmailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:refuse))

    log_automatic_dossier_operation(:refuser, self)
    emit_webhook_event(:dossier_refuse)
  end

  def after_commit_refuser_automatiquement
    enqueue_attestation_generation

    if procedure.accuse_lecture?
      NotificationMailer.send_accuse_lecture_notification(self).deliver_later
    else
      NotificationMailer.send_refuse_notification(self).deliver_later
    end
    NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
    enqueue_ami_notification

    send_dossier_decision_to_experts(self)
    clean_champs_after_instruction!
  end

  def after_classer_sans_suite(h)
    instructeur = h[:instructeur]
    motivation = h[:motivation]
    justificatif = h[:justificatif]

    self.processed_at = self.traitements
      .classer_sans_suite(motivation: motivation, instructeur: instructeur)
      .processed_at
    self.expired_at = expiration_date
    attestation&.destroy

    save!

    if justificatif
      self.justificatif_motivation.attach(justificatif)
    end

    save!

    EmailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:sans_suite))

    log_dossier_operation(instructeur, :classer_sans_suite, self)
    emit_webhook_event(:dossier_sans_suite)
  end

  def after_commit_classer_sans_suite(h)
    disable_notification = h.fetch(:disable_notification, false)

    if !disable_notification
      if procedure.accuse_lecture?
        NotificationMailer.send_accuse_lecture_notification(self).deliver_later
      else
        NotificationMailer.send_sans_suite_notification(self).deliver_later
      end
      NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
      enqueue_ami_notification
    end

    send_dossier_decision_to_experts(self)
    clean_champs_after_instruction!
    remove_attente_avis_notification
  end

  def after_repasser_en_instruction(h)
    instructeur = h[:instructeur]

    create_missing_traitemets

    self.hidden_by_user_at = nil
    self.archived = false
    self.termine_close_to_expiration_notice_sent_at = nil
    self.conservation_extension = 0.days
    self.en_instruction_at = self.traitements
      .passer_en_instruction(instructeur: instructeur)
      .processed_at
    self.expired_at = expiration_date
    attestation&.destroy

    self.sva_svr_decision_on = nil
    self.motivation = nil
    self.justificatif_motivation.purge_later

    save!

    EmailTemplatePresenterService.create_commentaire_for_state(self, DossierOperationLog.operations.fetch(:repasser_en_instruction))

    log_dossier_operation(instructeur, :repasser_en_instruction)
    emit_webhook_event(:dossier_repasse_en_instruction)
  end

  def after_commit_repasser_en_instruction(h)
    disable_notification = h.fetch(:disable_notification, false)

    if !disable_notification
      NotificationMailer.send_repasser_en_instruction_notification(self).deliver_later
      NotificationMailer.send_notification_for_tiers(self, repasser_en_instruction: true).deliver_later if self.for_tiers?
      enqueue_ami_notification(state: :repasser_en_instruction)
    end

    DossierNotification.destroy_notifications_by_dossier_and_type(self, :dossier_expirant)

    rebase_later
  end

  def clean_champs_after_submit!
    remove_not_in_revision_champs!
    remove_discarded_rows!
    remove_not_visible_or_empty_repetitions!
    clear_not_visible_or_empty_champs!
    clear_france_connect_champs_piece_justificatives!
  end

  def clean_champs_after_instruction!
    remove_discarded_rows!
    clear_titres_identite!
    clear_auto_purged_piece_justificatives!
  end

  # Emits once the surrounding transaction (if any) is committed, so the event
  # row and its delivery job are never rolled back with the business change.
  #
  # Ordering contract: call this from INSIDE the business transaction (the
  # aasm `after` callback), in causal order — the registered blocks run FIFO
  # at the real commit, so event ids follow the order of the calls even when
  # a transition nests an automatic one. Never emit from an aasm
  # `after_commit` callback: at the real commit the inner transition's commit
  # hooks run before the outer's, which would give the consequence
  # (dossier_accepte) a lower id than its cause (dossier_depose).
  def emit_webhook_event(event_type)
    # Fail fast, and at the emit site: a type missing from EVENT_TYPES would
    # otherwise be a permanent silent no-op (EmitEventService matches zero
    # subscriptions and records nothing), and inside the deferred block the
    # service's rescue would downgrade the bug to a Sentry event.
    if !Webhook::EVENT_TYPES.include?(event_type.to_s)
      raise ArgumentError, "unknown webhook event type: #{event_type}"
    end

    ActiveRecord.after_all_transactions_commit do
      Webhooks::EmitEventService.call(dossier: self, event_type:)
    end
  end

  private

  def remove_not_in_revision_champs!
    champ_data.where.not(stable_id: revision_stable_ids).where(stream: Dossier::MAIN_STREAM).destroy_all
  end

  def remove_discarded_rows!
    row_to_remove_ids = champ_data.filter { _1.row? && _1.discarded? }.map(&:row_id)

    return if row_to_remove_ids.empty?
    champ_data.where(row_id: row_to_remove_ids, stream: Dossier::MAIN_STREAM).destroy_all
  end

  def remove_not_visible_or_empty_repetitions!
    row_to_remove_ids = root_champs_public
      .filter { _1.repetition? && (_1.blank? || !_1.visible?) }
      .flat_map(&:row_ids)

    return if row_to_remove_ids.empty?
    champ_data.where(row_id: row_to_remove_ids, stream: Dossier::MAIN_STREAM).destroy_all
  end

  def clear_not_visible_or_empty_champs!
    champs_to_clear = flat_champs_public
      .reject(&:repetition?)
      .filter { _1.blank? || !_1.visible? }

    champ_data.where(id: champs_to_clear, stream: Dossier::MAIN_STREAM).find_each(&:clear)
  end

  def clear_france_connect_champs_piece_justificatives!
    champs_to_clear_ids = root_champs_public.filter(&:france_connect?).map(&:stable_id)

    return if champs_to_clear_ids.empty?
    champ_data.where(stable_id: champs_to_clear_ids, stream: Dossier::MAIN_STREAM).find_each(&:clear_piece_justificative)
  end

  def clear_titres_identite!
    champ_to_clear_stable_ids = champ_data.filter do |champ|
      # Use STI type to avoid querying type_de_champ for orphaned champ_data
      next false unless champ.is_a?(Champs::PieceJustificativeChamp)

      begin
        # because of revisions, champ.type can differ from champ.type_de_champ.type_champ
        # (e.g. piece_justificative → iban): the type_de_champ then has no titre_identite?
        champ.is_type?(champ.type_de_champ.type_champ) && champ.titre_identite?
      rescue RuntimeError
        # Champ has no type_de_champ in current revision (orphaned), skip it
        false
      end
    end.to_set(&:stable_id)

    champ_data.where(stable_id: champ_to_clear_stable_ids).find_each(&:clear)
  end

  def clear_auto_purged_piece_justificatives!
    revision_ids = revision.draft? ? [procedure.draft_revision_id] : (procedure.revisions.ids - [procedure.draft_revision_id])
    champ_to_clear_stable_ids = TypeDeChamp.joins(:revision_type_de_champs)
      .where(procedure_revision_types_de_champ: { revision_id: revision_ids }, type_champ: 'piece_justificative')
      .order(updated_at: :desc)
      .uniq(&:stable_id)
      .filter(&:pj_auto_purge?)
      .map(&:stable_id)

    champ_data.where(stable_id: champ_to_clear_stable_ids).find_each(&:clear)
  end

  def remove_attente_avis_notification
    DossierNotification.destroy_notifications_by_dossier_and_type(self, :attente_avis)
  end

  def remove_auto_purged_piece_justificatives!
    champ_to_remove_ids = filled_champs.filter { |c| c.piece_justificative? && c.pj_auto_purge? }.map(&:id)

    return if champ_to_remove_ids.empty?

    champ_data.where(id: champ_to_remove_ids, stream: Dossier::MAIN_STREAM).destroy_all
  end

  def enqueue_ami_notification(trigger: :dossier_state_change, state: nil)
    Ami::CreateNotificationService.call(dossier: self, trigger:, state:)
  end
end
