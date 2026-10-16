# frozen_string_literal: true

class Webhook < ApplicationRecord
  MAX_PER_PROCEDURE = 50
  URL_MAX_LENGTH = 2048
  LABEL_MAX_LENGTH = 255
  SECRET_PREFIX = "whsec_"
  SECRET_BYTES = 32
  SECRET_OVERLAP_DEFAULT = 24.hours
  SECRET_OVERLAP_MAX = 7.days
  # https://www.standardwebhooks.com retry schedule
  RETRY_SCHEDULE = [5.seconds, 5.minutes, 30.minutes, 2.hours, 5.hours, 10.hours, 14.hours, 20.hours, 24.hours].freeze
  MAX_ATTEMPTS = RETRY_SCHEDULE.size + 1
  RETRY_JITTER = 0.1

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

  belongs_to :procedure, inverse_of: :webhooks

  kredis_flag :debounce_delivery_flag

  encrypts :secret
  encrypts :previous_secret

  validates :url, presence: true, url: true
  validates :url, length: { maximum: URL_MAX_LENGTH }
  validates :label, length: { maximum: LABEL_MAX_LENGTH }
  validates :event_types, presence: true
  validate :event_types_are_known
  validate :webhooks_count_within_limit, on: :create

  before_validation :generate_secret, on: :create
  before_create :initialize_cursor
  before_update :sync_event_type_floors
  before_update :invalidate_delivery_claim
  before_update :forget_previous_endpoint_backoff, if: :url_changed?

  scope :deliverable, -> { where(enabled: true).where(procedure_id: Procedure.kept.select(:id)) }
  scope :subscribed_to, -> (event_type) { where("? = ANY(event_types)", event_type) }

  def pending_events
    scope = WebhookEvent
      .where(procedure_id:)
      .where("id > ?", cursor)
      .where(event_type: event_types)

    # a floor the cursor has passed filters nothing
    event_type_floors.each do |event_type, floor|
      next if floor <= cursor

      scope = scope.where("NOT (event_type = ? AND id <= ?)", event_type, floor)
    end

    scope
  end

  def self.generate_secret
    "#{SECRET_PREFIX}#{Base64.strict_encode64(SecureRandom.random_bytes(SECRET_BYTES))}"
  end

  # The previous secret keeps signing for `overlap`; zero revokes it at once.
  def renew_secret!(overlap: SECRET_OVERLAP_DEFAULT)
    update!(
      secret: self.class.generate_secret,
      previous_secret: overlap.positive? ? secret : nil,
      previous_secret_expires_at: overlap.positive? ? overlap.from_now : nil
    )
  end

  def previous_secret_valid?
    previous_secret_expires_at.present? && previous_secret_expires_at.future?
  end

  def signing_secrets
    [secret, (previous_secret if previous_secret_valid?)].compact
  end

  def in_backoff?
    retry_at.present? && retry_at.future?
  end

  def retry_delay
    RETRY_SCHEDULE.fetch(consecutive_failures - 1, RETRY_SCHEDULE.last) * rand((1 - RETRY_JITTER)..(1 + RETRY_JITTER))
  end

  # One scheduled run per lag window: it delivers the events emitted
  # meanwhile, or schedules a follow-up for those still inside the lag.
  def schedule_delivery
    lag = Webhooks::DeliveryJob::SAFETY_LAG
    # nil when Redis is unavailable: schedule anyway
    return if debounce_delivery_flag.mark(expires_in: lag, force: false) == false

    Webhooks::DeliveryJob.set(wait: lag).perform_later(id)
  end

  def reactivate!
    update!(enabled: true, auto_disabled_at: nil, consecutive_failures: 0, retry_at: nil, last_error: nil, delivery_claimed_at: nil)
  end

  # Keeps the claim, unlike reactivate!: a run may be in flight.
  def clear_backoff!
    update!(consecutive_failures: 0, retry_at: nil, last_error: nil)
  end

  private

  def generate_secret
    self.secret ||= self.class.generate_secret
  end

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

  def initialize_cursor
    self.cursor = WebhookEvent.where(procedure_id:).maximum(:id) || 0
  end

  # An event type added later only receives events emitted after the change.
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

  # The backoff was earned by the previous endpoint.
  def forget_previous_endpoint_backoff
    self.consecutive_failures = 0
    self.retry_at = nil
    self.last_error = nil
  end

  # Stops an in-flight run working on the old subscription.
  def invalidate_delivery_claim
    self.delivery_claimed_at = nil if event_types_changed? || url_changed?
  end
end
