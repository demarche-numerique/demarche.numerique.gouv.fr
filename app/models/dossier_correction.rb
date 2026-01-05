# frozen_string_literal: true

class DossierCorrection < ApplicationRecord
  belongs_to :dossier
  belongs_to :commentaire

  validates_associated :commentaire

  scope :pending, -> { where(resolved_at: nil, cancelled_at: nil) }

  enum :reason, {
    incorrect: 'incorrect',
    incomplete: 'incomplete',
    outdated: 'outdated',
  }, prefix: :dossier

  def resolved?
    resolved_at.present?
  end

  def resolve
    self.resolved_at = Time.current
    destroy_attente_correction_notification
  end

  def resolve!
    resolve
    save!
  end

  def pending? = !resolved? && !cancelled?

  def cancelled?
    cancelled_at.present?
  end

  def cancel!
    update!(cancelled_at: Time.current)
    resolve! unless resolved?
  end

  def resolved_by_modification?
    return false if !resolved?

    dossier
      .traitements
      .en_construction
      .exists?(processed_at: self.created_at..self.resolved_at)
  end
end

private

def destroy_attente_correction_notification
  DossierNotification.destroy_notifications_by_dossier_and_type(dossier, :attente_correction)
end
