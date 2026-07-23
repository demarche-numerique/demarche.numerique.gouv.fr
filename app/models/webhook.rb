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

  # Default-scoped (kept): a discarded démarche reads as nil here, which is
  # how the API hides it (see Api::V2::Context#authorized_demarche?) and why
  # delivery goes through the `deliverable` scope rather than this association.
  belongs_to :procedure, inverse_of: :webhooks

  encrypts :secret
  has_secure_token :secret, length: 48

  validates :url, presence: true, url: { no_local: true }, no_private_ip_url: true
  validates :event_types, presence: true
  validate :event_types_are_known
  validate :webhooks_count_within_limit, on: :create

  before_create :initialize_cursor
  before_update :sync_event_type_floors
  before_update :invalidate_delivery_claim

  # Deliverability is `enabled` — admin-owned, auto-disable flips it off too,
  # keeping auto_disabled_at as pure diagnostics of why (see
  # Webhooks::DeliveryJob#register_failure and #reactivate!) — plus a kept
  # démarche: discarding one suspends its integration without touching
  # `enabled`, so Procedure#restore resumes deliveries by construction.
  scope :deliverable, -> { where(enabled: true).where(procedure_id: Procedure.kept.select(:id)) }
  scope :subscribed_to, -> (event_type) { where("? = ANY(event_types)", event_type) }

  # Events this webhook still has to deliver, event type floors applied (see
  # #sync_event_type_floors). Single definition shared by Webhooks::DeliveryJob
  # (which adds batching and the safety lag) and the delivery sweeper (which
  # only checks existence): the two must never disagree on what is pending,
  # or the sweeper re-enqueues no-op deliveries forever.
  def pending_events
    scope = WebhookEvent
      .where(procedure_id:)
      .where("id > ?", cursor)
      .where(event_type: event_types)

    event_type_floors.each do |event_type, floor|
      scope = scope.where("NOT (event_type = ? AND id <= ?)", event_type, floor)
    end

    scope
  end

  def backoff_delay
    RETRY_BASE_INTERVAL * (2**[consecutive_failures - 1, 0].max)
  end

  def in_backoff?
    consecutive_failures > 0 && last_attempt_at.present? && Time.current < last_attempt_at + backoff_delay
  end

  # Also clears the delivery claim: a claim left by a crashed worker would
  # otherwise silently delay the catch-up delivery webhookActiver promises
  # until the claim ages past its TTL. A delivery genuinely in flight
  # notices the lost claim after its next HTTP call and stops without
  # further bookkeeping (see Webhooks::DeliveryJob#deliver_pending_events).
  def reactivate!
    update!(enabled: true, auto_disabled_at: nil, consecutive_failures: 0, last_error: nil, delivery_claimed_at: nil)
  end

  # Lifts a pending backoff without touching the delivery claim: used by
  # webhookActiver on an already-enabled webhook, where clearing the claim
  # would hand an in-flight run's work to a concurrent second job.
  def clear_backoff!
    update!(consecutive_failures: 0, last_error: nil)
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

  # A subscription change invalidates any in-flight delivery run in the same
  # transaction: the run's compare-and-swap on delivery_claimed_at then fails
  # (see Webhooks::DeliveryJob#advance_cursor), so a cursor computed under the
  # old event_types can never skip an event only the new ones select, and no
  # batch keeps flowing to a replaced URL.
  def invalidate_delivery_claim
    self.delivery_claimed_at = nil if event_types_changed? || url_changed?
  end
end
