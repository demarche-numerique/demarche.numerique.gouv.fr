# frozen_string_literal: true

module DossierStateConcern
  extend ActiveSupport::Concern

  def usager_submit_en_construction!
    self.traitements.usager_submit_en_construction
    self.submitted_revision_id = revision_id
    save!

    RoutingEngine.compute(self)

    resolve_pending_correction!
    process_sva_svr!
    clean_champs_after_submit!
    DossierNotification.create_notification(self, :dossier_modifie)
  end

  def instructeur_submit_en_construction!(instructeur:)
    self.traitements.instructeur_submit_en_construction(instructeur:)
    save!

    RoutingEngine.compute(self)
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

    MailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:en_construction))
    procedure.compute_dossiers_count

    process_declarative!
    process_sva_svr!

    index_search_terms_later
  end

  def after_commit_passer_en_construction
    NotificationMailer.send_en_construction_notification(self).deliver_later
    NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
    groupe_instructeur.instructeurs.with_instant_email_new_dossier(self.procedure).each do |instructeur|
      DossierMailer.notify_new_dossier_depose_to_instructeur(self, instructeur.email).deliver_later
    end
    DossierNotification.create_notification(self, :dossier_depose) if !procedure.declarative? && !procedure.sva_svr_enabled?

    clean_champs_after_submit!
  end

  def after_passer_en_instruction(h)
    instructeur = h[:instructeur]
    instructeur.follow(self)

    self.en_construction_close_to_expiration_notice_sent_at = nil
    self.conservation_extension = 0.days
    self.en_instruction_at = self.traitements
      .passer_en_instruction(instructeur: instructeur)
      .processed_at
    self.expired_at = expiration_date

    save!

    reset_user_buffer_stream!
    reset_instructeur_buffer_stream!
    with_champs

    MailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:en_instruction))
    resolve_pending_correction!

    log_dossier_operation(instructeur, :passer_en_instruction)
  end

  def after_commit_passer_en_instruction(h)
    disable_notification = h.fetch(:disable_notification, false)

    if !disable_notification
      NotificationMailer.send_en_instruction_notification(self).deliver_later
      NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
    end

    DossierNotification.destroy_notifications_by_dossier_and_type(self, :dossier_expirant)
  end

  def after_passer_automatiquement_en_instruction
    self.en_construction_close_to_expiration_notice_sent_at = nil
    self.conservation_extension = 0.days
    self.en_instruction_at = traitements.passer_en_instruction.processed_at
    self.expired_at = expiration_date

    if procedure.declarative_en_instruction?
      self.declarative_triggered_at = en_instruction_at
    end

    save!

    MailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:en_instruction))

    if procedure.sva_svr_enabled?
      log_automatic_dossier_operation(:passer_en_instruction, self)
    else
      log_automatic_dossier_operation(:passer_en_instruction)
    end
  end

  def after_commit_passer_automatiquement_en_instruction
    NotificationMailer.send_en_instruction_notification(self).deliver_later
    NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?
    DossierNotification.destroy_notifications_by_dossier_and_type(self, :dossier_depose)
  end

  def after_repasser_en_construction(h)
    instructeur = h[:instructeur]

    create_missing_traitemets

    self.en_construction_close_to_expiration_notice_sent_at = nil
    self.conservation_extension = 0.days
    self.en_construction_at = self.traitements
      .passer_en_construction(instructeur: instructeur)
      .processed_at
    self.expired_at = expiration_date

    save!

    log_dossier_operation(instructeur, :repasser_en_construction)
  end

  def after_commit_repasser_en_construction
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

    MailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:accepte))

    log_dossier_operation(instructeur, :accepter, self)
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

    MailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:accepte))

    log_automatic_dossier_operation(:accepter, self)
  end

  def after_commit_accepter_automatiquement
    enqueue_attestation_generation

    if procedure.accuse_lecture?
      NotificationMailer.send_accuse_lecture_notification(self).deliver_later
    else
      NotificationMailer.send_accepte_notification(self).deliver_later
    end
    NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?

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

    MailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:refuse))

    log_dossier_operation(instructeur, :refuser, self)
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

    MailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:refuse))

    log_automatic_dossier_operation(:refuser, self)
  end

  def after_commit_refuser_automatiquement
    enqueue_attestation_generation

    if procedure.accuse_lecture?
      NotificationMailer.send_accuse_lecture_notification(self).deliver_later
    else
      NotificationMailer.send_refuse_notification(self).deliver_later
    end
    NotificationMailer.send_notification_for_tiers(self).deliver_later if self.for_tiers?

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

    save!

    if justificatif
      self.justificatif_motivation.attach(justificatif)
    end

    save!

    MailTemplatePresenterService.create_commentaire_for_state(self, Dossier.states.fetch(:sans_suite))

    log_dossier_operation(instructeur, :classer_sans_suite, self)
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

    MailTemplatePresenterService.create_commentaire_for_state(self, DossierOperationLog.operations.fetch(:repasser_en_instruction))

    log_dossier_operation(instructeur, :repasser_en_instruction)
  end

  def after_commit_repasser_en_instruction(h)
    disable_notification = h.fetch(:disable_notification, false)

    if !disable_notification
      NotificationMailer.send_repasser_en_instruction_notification(self).deliver_later
      NotificationMailer.send_notification_for_tiers(self, repasser_en_instruction: true).deliver_later if self.for_tiers?
    end

    DossierNotification.destroy_notifications_by_dossier_and_type(self, :dossier_expirant)

    rebase_later
  end

  def clean_champs_after_submit!
    remove_not_in_revision_champs!
    remove_discarded_rows!
    remove_not_visible_or_empty_repetitions!
    clear_not_visible_or_empty_champs!
  end

  def clean_champs_after_instruction!
    remove_discarded_rows!
    clear_titres_identite!
    clear_auto_purged_piece_justificatives!
  end

  private

  def remove_not_in_revision_champs!
    champs.where.not(stable_id: revision_stable_ids).where(stream: Champ::MAIN_STREAM).destroy_all
  end

  def remove_discarded_rows!
    row_to_remove_ids = champs.filter { _1.row? && _1.discarded? }.map(&:row_id)

    return if row_to_remove_ids.empty?
    champs.where(row_id: row_to_remove_ids, stream: Champ::MAIN_STREAM).destroy_all
  end

  def remove_not_visible_or_empty_repetitions!
    row_to_remove_ids = project_champs_public
      .filter { _1.repetition? && (_1.blank? || !_1.visible?) }
      .flat_map(&:row_ids)

    return if row_to_remove_ids.empty?
    champs.where(row_id: row_to_remove_ids, stream: Champ::MAIN_STREAM).destroy_all
  end

  def clear_not_visible_or_empty_champs!
    champs_to_clear = project_champs_public_all
      .reject(&:repetition?)
      .filter { _1.blank? || !_1.visible? }

    champs.where(id: champs_to_clear, stream: Champ::MAIN_STREAM).find_each(&:clear)
  end

  def clear_titres_identite!
    champ_to_clear_stable_ids = champs.filter { _1.class == Champs::TitreIdentiteChamp }.to_set(&:stable_id)
    champs.where(stable_id: champ_to_clear_stable_ids).find_each(&:clear)
  end

  def clear_auto_purged_piece_justificatives!
    revision_ids = revision.draft? ? [procedure.draft_revision_id] : (procedure.revisions.ids - [procedure.draft_revision_id])
    champ_to_clear_stable_ids = TypeDeChamp.joins(:revision_types_de_champ)
      .where(procedure_revision_types_de_champ: { revision_id: revision_ids }, type_champ: 'piece_justificative')
      .order(updated_at: :desc)
      .uniq(&:stable_id)
      .filter(&:pj_auto_purge?)
      .map(&:stable_id)

    champs.where(stable_id: champ_to_clear_stable_ids).find_each(&:clear)
  end

  def remove_attente_avis_notification
    DossierNotification.destroy_notifications_by_dossier_and_type(self, :attente_avis)
  end

  def remove_auto_purged_piece_justificatives!
    champ_to_remove_ids = filled_champs.filter { |c| c.piece_justificative? && c.pj_auto_purge? }.map(&:id)

    return if champ_to_remove_ids.empty?

    champs.where(id: champ_to_remove_ids, stream: Champ::MAIN_STREAM).destroy_all
  end
end
