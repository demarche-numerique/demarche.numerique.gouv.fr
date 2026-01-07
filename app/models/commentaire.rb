# frozen_string_literal: true

class Commentaire < ApplicationRecord
  include Discard::Model
  belongs_to :dossier, inverse_of: :commentaires, touch: true, optional: false
  belongs_to :instructeur, inverse_of: :commentaires, optional: true
  belongs_to :expert, inverse_of: :commentaires, optional: true
  has_one :dossier_correction, inverse_of: :commentaire, dependent: :nullify
  has_one :dossier_pending_response, inverse_of: :commentaire, dependent: :nullify

  validate :messagerie_available?, on: :create, unless: -> { dossier.brouillon? }

  has_many_attached :piece_jointe

  validates :body, presence: { message: "ne peut être vide" }, unless: :discarded?

  normalizes :body, with: NORMALIZES_NON_PRINTABLE_PROC

  FILE_MAX_SIZE = 20.megabytes
  SYSTEM_EMAILS = [CONTACT_EMAIL, OLD_CONTACT_EMAIL.split(",")].flatten

  validates :piece_jointe,
    content_type: AUTHORIZED_CONTENT_TYPES,
    size: { less_than: FILE_MAX_SIZE }

  scope :chronological, -> { order(created_at: :asc) }
  scope :updated_since?, -> (date) { where('commentaires.updated_at > ?', date) }
  scope :sent_by_usager, -> { where(instructeur_id: nil, expert_id: nil) }
  scope :sent_by_instructeur, -> { where.not(instructeur_id: nil) }
  scope :to_notify, -> (instructeur_id) {
    where.not(email: SYSTEM_EMAILS)
      .where(discarded_at: nil)
      .where("instructeur_id IS NULL OR instructeur_id != ?", instructeur_id)
  }

  after_create :notify

  def self.mark_usager_messages_as_seen(dossier)
    where(dossier: dossier)
      .sent_by_usager
      .where(seen_by_recipient_at: nil)
      .update_all(seen_by_recipient_at: Time.current)
  end

  def self.mark_instructeur_messages_as_seen(dossier)
    where(dossier: dossier)
      .sent_by_instructeur
      .where(seen_by_recipient_at: nil)
      .update_all(seen_by_recipient_at: Time.current)
  end

  def email
    if sent_by_instructeur?
      instructeur.email
    elsif sent_by_expert?
      expert.email
    else
      read_attribute(:email)
    end
  end

  def header
    "#{redacted_email}, #{I18n.l(created_at, format: '%d %b %Y %H:%M')}"
  end

  def redacted_email
    if sent_by_instructeur?
      if dossier.procedure.hide_instructeurs_email?
        "Instructeur n° #{instructeur.id}"
      else
        instructeur.email.split('@').first
      end
    else
      email
    end
  end

  def sent_by_system?
    SYSTEM_EMAILS.any? { email.include?(it) }
  end

  def sent_by_instructeur?
    instructeur_id.present?
  end

  def sent_by_expert?
    expert_id.present?
  end

  def sent_by_usager?
    !(sent_by_system? || sent_by_instructeur? || sent_by_expert?)
  end

  def sent_by?(someone)
    someone.present? && email == someone&.email
  end

  def soft_deletable?(connected_user)
    sent_by?(connected_user) &&
      (sent_by_instructeur? || sent_by_expert?) &&
      !discarded? &&
      !dossier_correction&.pending?
  end

  def can_cancel_correction?(connected_user)
    dossier_correction&.pending? &&
      sent_by?(connected_user) &&
      !discarded? &&
      sent_by_instructeur?
  end

  def cancel_correction!
    dossier_correction&.cancel!
  end

  def soft_delete!
    transaction do
      discard!
      dossier_pending_response&.respond!
      update! body: ''
    end

    piece_jointe.each(&:purge_later) if piece_jointe.attached?
  end

  def flagged_pending_correction?
    DossierCorrection.exists?(commentaire: self)
  end

  private

  def notify
    # - If the email is the contact email, the commentaire is a copy
    #   of an automated notification email we sent to a user, so do nothing.
    # - If a user or an invited user posted a commentaire, do nothing,
    #   the notification system will properly
    # - Otherwise, a instructeur posted a commentaire, we need to notify the user
    if sent_by_instructeur? || sent_by_expert?
      notify_user(wait: 5.minutes)
    elsif !sent_by_system?
      notify_administration
    end
  end

  def notify_user(job_options = {})
    if flagged_pending_correction?
      DossierMailer.with(commentaire: self).notify_pending_correction.deliver_later(job_options)
    else
      DossierMailer.with(commentaire: self).notify_new_answer.deliver_later(job_options)
    end
  end

  def notify_administration
    dossier.followers_instructeurs
      .with_instant_email_new_message(dossier.procedure)
      .find_each do |instructeur|
      DossierMailer.notify_new_commentaire_to_instructeur(dossier, instructeur.email).deliver_later
    end

    experts_contactes = Set.new

    dossier.avis.includes(:expert).find_each do |avis|
      expert_procedure = avis.expert.experts_procedures.find_by(procedure_id: dossier.procedure.id)
      if expert_procedure.notify_on_new_message? && avis.expert.present?
        expert_id = avis.expert.id
        if !experts_contactes.include?(expert_id)
          AvisMailer.notify_new_commentaire_to_expert(dossier, avis, avis.expert).deliver_later
          experts_contactes.add(expert_id)
        end
      end
    end
  end

  def messagerie_available?
    return if sent_by_system?
    if dossier.present? && !dossier.messagerie_available?
      errors.add(:dossier, "Il n’est pas possible d’envoyer un message sur un dossier supprimé, à archiver ou en brouillon")
    end
  end
end
