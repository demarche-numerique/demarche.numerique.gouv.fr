# frozen_string_literal: true

require 'addressable/uri'

class WebHookJob < ApplicationJob
  queue_as :default

  TIMEOUT = 10

  def perform(procedure_id, dossier_id, state, updated_at)
    procedure = Procedure.find(procedure_id)

    body = {
      procedure_id: procedure_id,
      dossier_id: dossier_id,
      state: state,
      updated_at: updated_at,
    }

    response = Typhoeus.post(procedure.web_hook_url, body: body, timeout: TIMEOUT)

    if !response.success?
      Sentry.set_tags(procedure: procedure_id, dossier: dossier_id)
      Sentry.set_extras(web_hook_url: sanitized_url(procedure.web_hook_url))
      Sentry.capture_message("Webhook error code: #{response.code} (#{response.return_message}) // Response: #{response.body}")
    end
  end

  private

  def sanitized_url(url)
    uri = Addressable::URI.parse(url)
    "#{uri.scheme}://#{uri.host}#{uri.path}"
  rescue Addressable::URI::InvalidURIError
    '(invalid URL)'
  end
end
