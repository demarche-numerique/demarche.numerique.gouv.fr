# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/api_token_mailer
class APITokenMailer < ApplicationMailer
  layout 'mailers/layout'

  # The co-recipients come as addresses, not records: an account merge destroys
  # the old administrateur, and a record that no longer deserializes makes the
  # delivery job discard the mail, the owner's notice included. They default to
  # none for the deliveries enqueued before co-administrators were warned.
  def expiration(api_token, co_recipient_emails = [])
    @api_token = api_token
    @co_recipient_emails = co_recipient_emails

    mail(to: api_token.administrateur.email, subject: default_i18n_subject(name: api_token.name, date: l(api_token.expires_at, format: :long)))
  end

  def expiration_for_co_administrator(api_token, administrateur, co_recipient_emails)
    @api_token = api_token
    @owner = api_token.administrateur
    @procedures_count = api_token.procedure_ids_shared_with(administrateur).size
    @other_recipient_emails = [@owner.email, *co_recipient_emails.excluding(administrateur.email)]

    mail(to: administrateur.email, subject: default_i18n_subject(email: @owner.email, date: l(api_token.expires_at, format: :long)))
  end

  def transfer_offered(api_token, recipient)
    @api_token = api_token
    @owner = api_token.administrateur

    mail(to: recipient.email, subject: default_i18n_subject(email: @owner.email))
  end

  # The answers come as plain values: the token may be deleted, or handed over
  # again, before the delivery job runs, and a record that no longer
  # deserializes makes it discard the mail.
  def transfer_accepted(api_token_name:, former_owner_email:, new_owner_email:)
    @api_token_name = api_token_name
    @new_owner_email = new_owner_email

    mail(to: former_owner_email, subject: default_i18n_subject(name: api_token_name))
  end

  def transfer_declined(api_token_name:, owner_email:, recipient_email:)
    @api_token_name = api_token_name
    @recipient_email = recipient_email

    mail(to: owner_email, subject: default_i18n_subject(name: api_token_name))
  end

  # One-off announcement sent when a token created without an expiration date is
  # given one. Grouped per administrateur: some of them own a dozen tokens.
  def becomes_expirable(user, api_tokens, expires_on)
    @api_tokens = api_tokens
    @expires_on = expires_on
    subject = "Votre accès à l’API de #{APPLICATION_NAME} expire le #{l(expires_on, format: :long)}"

    mail(to: user.email, subject:, reply_to: CONTACT_EMAIL)
  end

  # Every mail here tells who holds an API access, or when it stops working:
  # service information about a token the administrateur owns or owned, is
  # offered, or that reads their procedures, not outreach. Missing one means
  # discovering the outage or the change of hands in production, so they all
  # bypass unsubscriptions — the recurring notices most of all, since they land
  # when there is still time to act.
  #
  # Worth revisiting if this mailer ever carries something else.
  def self.critical_email?(action_name)
    true
  end
end
