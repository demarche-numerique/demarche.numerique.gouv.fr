# frozen_string_literal: true

if ENV.enabled?("MAILTRAP")
  ActiveSupport.on_load(:action_mailer) do
    module Mailtrap
      class SMTP < ::Mail::SMTP; end
    end

    ActionMailer::Base.add_delivery_method :mailtrap, Mailtrap::SMTP
    ActionMailer::Base.mailtrap_settings = {
      user_name: ENV.fetch("MAILTRAP_USERNAME"),
      password: ENV.fetch("MAILTRAP_PASSWORD"),
      address: ENV.fetch("MAILTRAP_ADDRESS", 'sandbox.smtp.mailtrap.io'),
      domain: ENV.fetch("MAILTRAP_DOMAIN", 'sandbox.smtp.mailtrap.io'),
      port: ENV.fetch("MAILTRAP_PORT", '2525'),
      authentication: ENV.fetch("MAILTRAP_AUTHENTICATION", :login),
    }
  end
end
