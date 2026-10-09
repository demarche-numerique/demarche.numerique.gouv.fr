# frozen_string_literal: true

class EmailEvent < ApplicationRecord
  RETENTION_DURATION = 1.month
  MESSAGE_IDS_HEADER = 'X-DN-Message-Ids'

  enum :status, {
    pending: 'pending',
    dispatched: 'dispatched',
    dispatch_error: 'dispatch_error',
  }

  scope :brevo, -> { where(method: 'brevo') }
  scope :outdated, -> { where(created_at: ...RETENTION_DURATION.ago) }

  class << self
    def create_from_message!(message, status:)
      recipients = message.to_addrs.presence || message.bcc_addrs
      message_ids = message[MESSAGE_IDS_HEADER]&.value.to_s.split(',')

      recipients.each_with_index do |recipient, index|
        EmailEvent.create!(
          to: recipient,
          subject: message.subject || "",
          processed_at: message.date,
          method: ActionMailer::Base.delivery_methods.key(message.delivery_method.class),
          message_id: message_ids[index] || message.message_id,
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
