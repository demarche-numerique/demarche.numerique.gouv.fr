# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/api_token_mailer
class APITokenMailer < ApplicationMailer
  layout 'mailers/layout'

  def expiration(api_token)
    @api_token = api_token
    user = api_token.administrateur.user
    subject = "Votre jeton d’accès à la plateforme #{APPLICATION_NAME} expire le #{l(@api_token.expires_at, format: :long)}"

    mail(to: user.email, subject:)
  end

  def self.critical_email?(action_name)
    false
  end
end
