# frozen_string_literal: true

class Cron::SendAPITokenExpirationNoticeJob < Cron::CronJob
  self.schedule_expression = "every day at 23:45"

  # `APIToken.expiring_within` is lower-bounded by `Date.today` (midnight), so a lost
  # run is only partly caught up: a token expiring in the 15 minutes before midnight
  # drops out of the scope for good, and one expiring the next day gets its 1-day
  # notice after it has expired. Its sibling SendAPIEntrepriseTokenExpirationNoticeJob
  # has no such lower bound (`expired_or_expires_soon?`) and does catch up, hence no
  # budget there. 5 retries span 7 minutes: a retry past midnight already runs the
  # next day's scope, and `expiration_notices_sent_at` keeps duplicates out.
  use_sidekiq_retry(max_retry: 5, report_after_attempts: 5)

  def perform
    windows = [
      1.day,
      1.week,
      1.month,
    ]

    windows.each do |window|
      APIToken
        .with_expiration_notice_to_send_for(window)
        .find_each do |token|
        co_recipients = token.expiration_co_recipients
        co_recipient_emails = co_recipients.map(&:email)
        APITokenMailer.expiration(token, co_recipient_emails).deliver_later
        co_recipients.each { APITokenMailer.expiration_for_co_administrator(token, it, co_recipient_emails).deliver_later }
        token.expiration_notices_sent_at << Time.zone.today
        token.save!
      end
    end
  end
end
