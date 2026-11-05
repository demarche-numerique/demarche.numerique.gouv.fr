# frozen_string_literal: true

module BrevoBlockableConcern
  extend ActiveSupport::Concern

  # Sent for a mail refused because the address already was: it says nothing
  # of the reason.
  BREVO_BLOCKED_EVENT = 'blocked'

  included do
    enum :brevo_blocked_reason, {
      hard_bounce: 'hard_bounce',
      spam: 'spam',
      unsubscribed: 'unsubscribed',
      invalid_email: 'invalid_email',
    }, prefix: :brevo_blocked_for
  end

  class_methods do
    def record_brevo_event(email:, event:, at:)
      return if !known_event?(event)

      find_by(email:)&.record_brevo_block!(at:, event:)
    end

    private

    def known_event?(event) = brevo_blocked_reasons.key?(event) || event == BREVO_BLOCKED_EVENT
  end

  # Events arrive in any order: each timestamp only moves forward, and the
  # state is read against brevo_unblocked_at.
  def record_brevo_block!(at:, event:)
    # a conditional UPDATE, not read-then-write: a concurrent event cannot move a timestamp backwards
    # (unscope: with the default eager_load, the WHERE would test a joined copy of users)
    users = User.unscope(:eager_load).where(id:)
    users.where(brevo_last_blocked_at: [nil, ...at]).update_all(brevo_last_blocked_at: at)
    return if event == BREVO_BLOCKED_EVENT

    users.where(brevo_blocked_reason_at: [nil, ..at]).update_all(brevo_blocked_reason: event, brevo_blocked_reason_at: at)
  end

  def brevo_blocked? = brevo_last_blocked_at.present? && (brevo_unblocked_at.nil? || brevo_last_blocked_at >= brevo_unblocked_at)
end
