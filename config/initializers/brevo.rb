# frozen_string_literal: true

if ENV.key?('BREVO_BALANCING_VALUE')
  require 'sib-api-v3-sdk'

  ActiveSupport.on_load(:action_mailer) do
    module Brevo
      class SMTP < ::Mail::SMTP; end
    end

    ActionMailer::Base.add_delivery_method :brevo, Brevo::SMTP
    ActionMailer::Base.brevo_settings = {
      user_name: ENV.fetch("BREVO_USER_NAME"),
      password: ENV.fetch("BREVO_SMTP_KEY"),
      address: ENV.fetch("BREVO_SMTP_ADDRESS", "smtp-relay.brevo.com"),
      domain: 'smtp-relay.brevo.com',
      port: ENV.fetch("BREVO_SMTP_PORT", 587).to_i,
      authentication: :cram_md5,
    }
  end

  SibApiV3Sdk.configure do |config|
    config.api_key['api-key'] = ENV["BREVO_API_V3_KEY"]
  end
end
