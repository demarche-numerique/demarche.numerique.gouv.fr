# frozen_string_literal: true

class DossierTransfer < ApplicationRecord
  has_many :dossiers, dependent: :nullify

  EXPIRATION_LIMIT = 2.weeks

  validates :email, strict_email: true, presence: true
  normalizes :email, with: -> (value) { EmailSanitizableConcern::EmailSanitizer.sanitize(value) }

  scope :pending, -> { where('"dossier_transfers"."created_at" > ?', (Time.zone.now - EXPIRATION_LIMIT)) }
  scope :stale, -> { where('"dossier_transfers"."created_at" <= ?', (Time.zone.now - EXPIRATION_LIMIT)) }
  scope :with_dossiers, -> { joins(:dossiers).merge(Dossier.visible_by_user) }
  scope :for_email, -> (email) { includes(dossiers: :user).with_dossiers.where(email: email) }

  after_create_commit :send_notification

  def self.initiate(email, dossiers)
    create(email: email, dossiers: dossiers)
  end

  def self.accept(id, current_user)
    transfer = pending.find_by(id: id, email: current_user.email)

    if transfer && transfer.dossiers.present?
      Invite
        .where(dossier: transfer.dossiers, email: transfer.email)
        .destroy_all
      DossierTransferLog.create(transfer.dossiers.map do |dossier|
        {
          dossier: dossier,
          from: dossier.user_email_for(:notification),
          from_support: transfer.from_support,
          to: transfer.email,
        }
      end)
      transfer.dossiers.update_all(user_id: current_user.id)
      transfer.destroy_and_nullify
    end
  end

  def user_locale
    User.find_by(email: email)&.locale || I18n.default_locale
  end

  def destroy_and_nullify
    transaction do
      # Rails cascading is not working with default scopes. Doing nullify cascade manually.
      dossiers.update_all(dossier_transfer_id: nil)
      destroy
    end
  end

  def self.destroy_stale
    transaction do
      # Rails cascading is not working with default scopes. Doing nullify cascade manually.
      Dossier.where(transfer: stale).update_all(dossier_transfer_id: nil)
      stale.destroy_all
    end
  end

  def sender
    if from_support?
      I18n.t("views.users.dossiers.transfers.sender_from_support")
    else
      sender_email
    end
  end

  def sender_email
    dossiers.last.user.email
  end

  private

  def send_notification
    DossierMailer.with(dossier_transfer: self).notify_transfer.deliver_later
  end
end
