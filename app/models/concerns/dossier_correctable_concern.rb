# frozen_string_literal: true

module DossierCorrectableConcern
  extend ActiveSupport::Concern

  A_CORRIGER = 'a_corriger'

  included do
    has_many :corrections, class_name: 'DossierCorrection', dependent: :destroy
    has_many :pending_corrections, -> { DossierCorrection.pending }, class_name: 'DossierCorrection', inverse_of: :dossier
    has_one :pending_correction, -> { DossierCorrection.pending }, class_name: 'DossierCorrection', inverse_of: :dossier

    scope :with_pending_corrections, -> { joins(:corrections).where(corrections: { resolved_at: nil }) }

    validate :validate_pending_correction, on: :champs_public_value
  end

  def flag_as_pending_correction!(commentaire, reason = nil)
    return unless may_flag_as_pending_correction?

    reason ||= :incorrect

    commentaire.dossier_correction = corrections.build(commentaire:, reason:)
    commentaire.dossier_correction.save!

    create_dossier_notifications(commentaire.instructeur)

    log_pending_correction_operation(commentaire, reason) if procedure.sva_svr_enabled?

    return if en_construction?

    repasser_en_construction_with_pending_correction!(instructeur: commentaire.instructeur)
  end

  def may_flag_as_pending_correction?
    return false if pending_corrections.exists?

    en_construction? || may_repasser_en_construction_with_pending_correction?
  end

  def pending_correction?
    # We don't want to show any alert if user is not allowed to modify the dossier
    return false unless en_construction?

    return pending_corrections.any? if pending_corrections.loaded?

    pending_corrections.exists?
  end

  def last_correction_resolved?
    corrections.last&.resolved?
  end

  def resolve_pending_correction
    pending_correction&.resolve
  end

  def resolve_pending_correction!
    resolve_pending_correction
    pending_correction&.save!

    pending_corrections.reset
  end

  def validate_pending_correction
    return unless procedure.sva_svr_enabled?
    return if pending_correction.nil? || pending_correction.resolved?

    errors.add(:pending_correction, :blank)
  end

  private

  def log_pending_correction_operation(commentaire, reason)
    operation = case reason.to_sym
    when :incorrect
      "demander_une_correction"
    when :incomplete
      "demander_a_completer"
    end

    log_dossier_operation(commentaire.instructeur, operation, commentaire)
  end

  def create_dossier_notifications(except_instructeur)
    DossierNotification.create_notification(self, :attente_correction)
    DossierNotification.create_notification(self, :message, except_instructeur:)
  end
end
