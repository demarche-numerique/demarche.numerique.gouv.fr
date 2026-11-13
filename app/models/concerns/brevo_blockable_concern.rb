# frozen_string_literal: true

module BrevoBlockableConcern
  extend ActiveSupport::Concern

  # Sent for a mail refused because the address already was: it says nothing
  # of the reason.
  BREVO_BLOCKED_EVENT = 'blocked'
  UNSUBSCRIBING_EVENTS = ['unsubscribed', 'spam'].freeze
  BREVO_UNBLOCK_INTERVAL = 24.hours

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
      # the webhook subscribes to the blocking events only: any other one is a misconfiguration
      if !known_event?(event)
        Sentry.capture_message("Brevo webhook: unhandled event", extra: { event: })
        return
      end

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
    users.update_all(email_unsubscribed: true) if event.in?(UNSUBSCRIBING_EVENTS)
  end

  def brevo_blocked? = brevo_last_blocked_at.present? && (brevo_unblocked_at.nil? || brevo_last_blocked_at >= brevo_unblocked_at)

  # At most once a day: an address that blocks again keeps its block until then.
  # An invalid address would only bounce.
  def unblock_brevo_for_critical_mail!
    return if !brevo_blocked? || brevo_blocked_for_invalid_email?
    return if brevo_unblocked_at&.after?(BREVO_UNBLOCK_INTERVAL.ago)
    return if !Brevo::API.new.unblock_user(email)

    update_columns(brevo_unblocked_at: Time.current)
  end
end
