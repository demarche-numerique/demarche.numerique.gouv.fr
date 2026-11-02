# frozen_string_literal: true

class WebhookController < ActionController::Base
  before_action :verify_crisp_signature!, only: [:crisp]
  before_action :verify_brevo_network!, only: [:brevo]
  before_action :verify_brevo_token!, only: [:brevo]
  skip_before_action :verify_authenticity_token

  def crisp
    # Note: always respond with 200 or webhooks will be suspended.
    Crisp::WebhookProcessor.new(params).process
    head :ok
  end

  def brevo
    User.record_brevo_event(email: params[:email], event: params[:event], at: Time.zone.at(params[:ts_event]))
    head :ok
  end

  private

  def verify_brevo_network!
    return if ENV['BREVO_WEBHOOK_NETWORKS'].blank?

    head :forbidden if !IPService.ip_in_networks?(request.remote_ip, ENV.fetch('BREVO_WEBHOOK_NETWORKS'))
  end

  def verify_brevo_token!
    return head :unauthorized if ENV['BREVO_WEBHOOK_TOKEN'].blank?

    authenticated = authenticate_with_http_token do |token|
      ActiveSupport::SecurityUtils.secure_compare(token, ENV.fetch("BREVO_WEBHOOK_TOKEN"))
    end

    head :unauthorized if !authenticated
  end

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
