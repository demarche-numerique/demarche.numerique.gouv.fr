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

  # One-off announcement sent when a token created without an expiration date is
  # given one. Grouped per administrateur: some of them own a dozen tokens.
  def becomes_expirable(user, api_tokens, expires_on)
    @api_tokens = api_tokens
    @expires_on = expires_on
    subject = "Votre accès à l’API de #{APPLICATION_NAME} expire le #{l(expires_on, format: :long)}"

    mail(to: user.email, subject:, reply_to: CONTACT_EMAIL)
  end

  # Every mail here announces that an API access is about to stop working, which
  # is service information about a resource the administrateur owns, not
  # outreach. Missing one means discovering the outage in production, so they all
  # bypass unsubscriptions — the recurring notices most of all, since they land
  # when there is still time to act.
  #
  # Worth revisiting if this mailer ever carries something that is not a
  # countdown to a broken integration.
  def self.critical_email?(action_name)
    true
  end
end
