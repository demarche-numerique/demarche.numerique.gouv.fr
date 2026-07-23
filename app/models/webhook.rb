# frozen_string_literal: true

class Webhook < ApplicationRecord
  MAX_PER_PROCEDURE = 50
  RETRY_BASE_INTERVAL = 10.seconds
  MAX_ATTEMPTS = 13

  EVENT_TYPES = %w[
    dossier_depose
    dossier_en_instruction
    dossier_accepte
    dossier_refuse
    dossier_sans_suite
    dossier_repasse_en_construction
    dossier_repasse_en_instruction
    dossier_modifie
    correction_demandee
    groupe_instructeur_change
    dossier_supprime
    dossier_restaure
    message_cree
    avis_cree
    avis_repondu
    dossier_label_ajoute
    dossier_label_supprime
  ].freeze

  # with_discarded: delivery bookkeeping (auto-disable notification) must keep
  # working for webhooks whose démarche has been discarded.
  belongs_to :procedure, -> { with_discarded }, inverse_of: :webhooks

  encrypts :secret
  has_secure_token :secret, length: 48

  validates :url, presence: true, url: { no_local: true }, no_private_ip_url: true
  validates :event_types, presence: true
  validate :event_types_are_known
  validate :webhooks_count_within_limit, on: :create

  before_create :initialize_cursor
  before_update :sync_event_type_floors

  scope :subscribed_to, -> (event_type) { where("? = ANY(event_types)", event_type) }
  scope :deliverable, -> { where(enabled: true, auto_disabled_at: nil) }

  def deliverable?
    enabled? && auto_disabled_at.nil?
  end

  def backoff_delay
    RETRY_BASE_INTERVAL * (2**[consecutive_failures - 1, 0].max)
  end

  def in_backoff?
    consecutive_failures > 0 && last_attempt_at.present? && Time.current < last_attempt_at + backoff_delay
  end

  def reactivate!
    update!(enabled: true, auto_disabled_at: nil, consecutive_failures: 0, last_error: nil)
  end

  private

  def event_types_are_known
    unknown = event_types - EVENT_TYPES
    if unknown.present?
      errors.add(:event_types, :invalid)
    end
  end

  # Soft limit: two concurrent creates can both pass this validation.
  def webhooks_count_within_limit
    if procedure.present? && procedure.webhooks.count >= MAX_PER_PROCEDURE
      errors.add(:base, :webhooks_limit_reached, limit: MAX_PER_PROCEDURE)
    end
  end

  # A new webhook must never receive events emitted before its creation.
  def initialize_cursor
    self.cursor = WebhookEvent.where(procedure_id:).maximum(:id) || 0
  end

  # Same contract on update: an event type added after creation must not
  # replay the backlog recorded while the webhook was not subscribed to it.
  # The floor marks the last event id recorded before the subscription
  # (see Webhooks::DeliveryJob#pending_events).
  def sync_event_type_floors
    return if !event_types_changed?

    added = event_types - (event_types_was || [])
    floors = event_type_floors.slice(*event_types)
    if added.any?
      latest = WebhookEvent.where(procedure_id:).maximum(:id) || 0
      floors = floors.merge(added.index_with { latest })
    end
    self.event_type_floors = floors
  end
end
