# frozen_string_literal: true

class Cron::TrustedDeviceTokenRenewalJob < Cron::CronJob
  self.schedule_expression = "every day at noon"

  def perform
    Instructeur
      .joins(:trusted_device_tokens)
      .merge(TrustedDeviceToken.expiring_in_one_week)
      .distinct
      .find_each do |instructeur|
        begin
          # Skip if the instructeur still has a valid token not yet approaching expiration,
          # or if we already sent a renewal email recently.
          # The goal is to send exactly one email before the *last* token expires.
          next if instructeur.trusted_device_tokens.renewal_not_needed.exists?

          tokens = instructeur.trusted_device_tokens

          ActiveRecord::Base.transaction do
            tokens.update_all(renewal_notified_at: Time.current)

            renewal_token = instructeur.create_trusted_device_token
            InstructeurMailer.trusted_device_token_renewal(
              instructeur, renewal_token,
              1.week.from_now
            ).deliver_later
          end
        rescue StandardError => e
          Sentry.capture_exception(e)
        end
      end
  end
end
