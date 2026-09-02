# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/administrateur_mailer
class AdministrateurMailer < ApplicationMailer
  layout 'mailers/layout'

  def activate_before_expiration(user, reset_password_token)
    @user = user
    @reset_password_token = reset_password_token
    @expiration_date = @user.reset_password_sent_at + Devise.reset_password_within
    @subject = "N’oubliez pas d’activer votre compte administrateur"

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: @subject,
      reply_to: CONTACT_EMAIL)
  end

  def notify_service_without_siret(user_email)
    @subject = "Siret manquant sur un de vos services"

    mail(to: user_email,
      subject: @subject,
      reply_to: CONTACT_EMAIL)
  end

  def api_token_expiration(user, tokens)
    @subject = "Renouvellement de jeton d'API nécessaire"
    @tokens = tokens

    mail(to: user.email,
      subject: @subject,
      reply_to: CONTACT_EMAIL)
  end

  def api_entreprise_token_expiration(administrateur, procedure)
    @procedure = procedure
    @expires_at = procedure.api_entreprise_token.expires_at

    mail(to: administrateur.user.email,
      subject: token_renewal_subject("API Entreprise", procedure, @expires_at),
      reply_to: CONTACT_EMAIL)
  end

  def self.critical_email?(action_name)
    action_name == "activate_before_expiration"
  end

  private

  def token_renewal_subject(api_name, procedure, expires_at)
    state = if expires_at.blank? # un jeton illisible n'a pas d'échéance à annoncer
      "n’est pas valide"
    elsif expires_at.past?
      "a expiré"
    else
      "expire bientôt"
    end

    "[Action requise] Votre jeton #{api_name} #{state} (démarche nº#{procedure.id})"
  end
end
