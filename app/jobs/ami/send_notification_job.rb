# frozen_string_literal: true

class Ami::SendNotificationJob < ApplicationJob
  include Dry::Monads[:result]

  use_sidekiq_retry(report_after_attempts: 8)

  queue_as :default

  def perform(payload, context = {})
    Sentry.set_tags(context)

    Rails.logger.debug { "AMI notification sending for dossier #{context[:dossier]}" }

    result = Ami::Client.new.send_notification(payload)

    case result
    in Success(_)
      Rails.logger.debug { "AMI notification sent successfully for dossier #{context[:dossier]}" }
    in Failure(error)
      Rails.logger.error("AMI notification failed for dossier #{context[:dossier]}: #{error}")
      raise "AMI notification failed for dossier #{context[:dossier]}: #{error}"
    end
  end
end
