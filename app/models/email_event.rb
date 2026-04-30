# frozen_string_literal: true

class EmailEvent < ApplicationRecord
  RETENTION_DURATION = 1.month

  enum :status, {
    pending: 'pending',
    dispatched: 'dispatched',
    dispatch_error: 'dispatch_error',
  }

  scope :brevo, -> { where(method: 'brevo') }
  scope :outdated, -> { where(created_at: ...RETENTION_DURATION.ago) }

  class << self
    def create_from_message!(message, status:)
      to = message.to_addrs || ["unset"] # no recipients when error occurs *before* setting to: in the mailer

      to.each do |recipient|
        EmailEvent.create!(
          to: recipient,
          subject: message.subject || "",
          processed_at: message.date,
          method: ActionMailer::Base.delivery_methods.key(message.delivery_method.class),
          message_id: message.message_id,
          status:
        )
      rescue StandardError => error
        Sentry.capture_exception(error, extra: { subject: message.subject, status: })
      end
    end
  end

  def domain
    to.split("@").last
  end
end
