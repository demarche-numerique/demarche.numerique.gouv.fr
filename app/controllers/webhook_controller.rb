# frozen_string_literal: true

class WebhookController < ActionController::Base
  before_action :verify_crisp_signature!, only: [:crisp]
  skip_before_action :verify_authenticity_token

  def crisp
    # Note: always respond with 200 or webhooks will be suspended.
    Crisp::WebhookProcessor.new(params).process
    head :ok
  end

  private

  def verify_crisp_signature!
    timestamp = request.headers['X-Crisp-Request-Timestamp']
    signature = request.headers['X-Crisp-Signature']

    return head :bad_request if signature.blank? || timestamp.blank?

    body = request.body.read
    concatenated_string = "[#{timestamp};#{body}]"

    expected_signature = OpenSSL::HMAC.hexdigest('sha256',
      ENV.fetch("CRISP_WEBHOOK_SECRET"),
      concatenated_string)

    head :bad_request unless ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end
end
