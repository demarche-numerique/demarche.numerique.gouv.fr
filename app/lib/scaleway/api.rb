# frozen_string_literal: true

class Scaleway::API
  include Dry::Monads[:result]

  API_URL = 'https://api.scaleway.com/transactional-email/v1alpha1/regions/fr-par/emails'
  CONSOLE_URL = 'https://console.scaleway.com/transactional-email/fr-par/domains'

  def properly_configured?
    secret_key.present?
  end

  def sent_mails(email_address)
    return [] unless properly_configured?

    result = API::Client.new.call(
      url: API_URL,
      params: { mail_rcpt: email_address, page_size: 100, order_by: 'created_at_desc' },
      headers: { 'X-Auth-Token' => secret_key },
      method: :get
    )

    case result
    in Success(body:)
      map_emails(body[:emails] || [])
    in Failure(code:, error:)
      Sentry.capture_message("Scaleway API error: #{error}", extra: { code: })
      []
    end
  end

  private

  def secret_key
    ENV.fetch('SCALEWAY_SECRET_KEY', nil)
  end

  def map_emails(emails)
    emails.map do |email|
      SentMail.new(
        from: email[:mail_from],
        to: email[:rcpt_to],
        subject: email[:subject],
        delivered_at: Time.zone.parse(email[:created_at]),
        status: email[:status],
        service_name: 'Scaleway',
        external_url: CONSOLE_URL
      )
    end
  end
end
