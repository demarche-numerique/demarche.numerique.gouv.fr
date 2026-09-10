# frozen_string_literal: true

class Avis < ApplicationRecord
  belongs_to :dossier, inverse_of: :avis, touch: true, optional: false
  belongs_to :experts_procedure, optional: false
  belongs_to :claimant, polymorphic: true, optional: false

  has_one_attached :piece_justificative_file
  has_one_attached :introduction_file
  has_one :expert, through: :experts_procedure
  has_one :procedure, through: :experts_procedure

  has_many :targeted_user_links, as: :target_model, dependent: :destroy, inverse_of: :target_model

  FILE_MAX_SIZE = 20.megabytes
  validates :piece_justificative_file,
    content_type: -> (_record) { AUTHORIZED_CONTENT_TYPES },
    size: { less_than: FILE_MAX_SIZE },
    empty_file: true

  validates :introduction_file,
    content_type: -> (_record) { AUTHORIZED_CONTENT_TYPES },
    size: { less_than: FILE_MAX_SIZE },
    empty_file: true

  validates :question_answer, inclusion: { in: [true, false] }, on: :update, if: -> { question_label.present? }
  # The expert's answer is the only validated update path (revocation only
  # touches answered avis, reminders and merges bypass validations).
  validates :answer, presence: true, on: :update
  validates :piece_justificative_file, size: { less_than: FILE_MAX_SIZE }
  validates :introduction_file, size: { less_than: FILE_MAX_SIZE }

  normalizes :question_label, with: -> (value) { value.strip.presence }
  # `.presence` keeps blank collapsed to nil: the with_answer/without_answer
  # scopes are nil-based while revoke_by!/remind_by! are presence-based — an
  # empty string would count as answered for the former and unanswered for
  # the latter.
  normalizes :answer, with: -> (value) { NORMALIZES_NON_PRINTABLE_PROC.call(value).presence }

  default_scope { joins(:dossier) }
  scope :with_answer, -> { where.not(answer: nil) }
  scope :without_answer, -> { where(answer: nil) }
  scope :for_dossier, -> (dossier_id) { where(dossier_id: dossier_id) }
  scope :by_latest, -> { order(updated_at: :desc) }
  scope :updated_since?, -> (date) { where('avis.updated_at > ?', date) }
  scope :termine_expired_after_notice_grace, -> { unscope(:joins).where(dossier: Dossier.termine_expired_after_notice_grace) }
  scope :not_hidden_by_administration, -> { where(dossiers: { hidden_by_administration_at: nil }) }
  # Both revocations cut the expert off: the avis itself (instructeur) or the
  # expert's whole link to the procedure (admin "révoquer l'expert"). Keep them
  # in a single scope so no call site can filter on one dimension only.
  scope :not_revoked, -> { joins(:experts_procedure).where(revoked_at: nil, experts_procedures: { revoked_at: nil }) }
  scope :not_termine, -> { where.not(dossiers: { state: Dossier::TERMINE }) }

  attr_accessor :invite_linked_dossiers

  def email_to_display
    expert&.email
  end

  def spreadsheet_columns
    [
      ['Dossier ID', dossier_id.to_s],
      ['Introduction', :introduction],
      ['Réponse', :answer],
      ['Question', :question_label],
      ['Réponse oui/non', :question_answer],
      ['Créé le', :created_at],
      ['Répondu le', :updated_at],
      ['Instructeur', claimant&.email],
      ['Expert', expert&.email],
    ]
  end

  def updated_recently?
    updated_at > 30.minutes.ago
  end

  def revoked?
    revoked_at.present?
  end

  def remindable_by?(reminder)
    revokable_by?(reminder)
  end

  def revokable_by?(revocator)
    revocator.dossiers.include?(dossier) || revocator == claimant
  end

  def revoke_by!(revocator)
    return false if !revokable_by?(revocator)

    if answer.present?
      update!(revoked_at: Time.zone.now)
    else
      destroy!
    end
  end

  def remind_by!(revocator)
    return false if !remindable_by?(revocator) || answer.present?
    update_column(:reminded_at, Time.zone.now)
  end
end
