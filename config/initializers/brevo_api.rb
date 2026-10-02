# frozen_string_literal: true

if ENV.key?('BREVO_API_BALANCING_VALUE')
  # Not ActiveSupport.on_load(:action_mailer) like brevo.rb: production.rb loads
  # ActionMailer::Base before the autoloader is ready.
  Rails.application.config.to_prepare do
    ActionMailer::Base.add_delivery_method :brevo_api, Brevo::APIDeliveryMethod
  end
end
