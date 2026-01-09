# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailer < ApplicationMailer
  layout 'mailers/layout'

  def new_account_warning(user, procedure = nil)
    @user = user
    @subject = "Demande de création de compte"
    @procedure = procedure

    mail(to: user.email, subject: @subject, procedure: @procedure)
  end

  def ask_for_merge(user, requested_email)
    @user = user
    @requested_email = requested_email
    @subject = "Fusion de compte"

    mail(to: requested_email, subject: @subject)
  end

  def france_connect_merge_confirmation(email, email_merge_token, email_merge_token_created_at)
    @email_merge_token = email_merge_token
    @email_merge_token_created_at = email_merge_token_created_at
    @subject = "Veuillez confirmer la fusion de compte"

    mail(to: email, subject: @subject)
  end

  def custom_confirmation_instructions(user, token)
    @user = user

    @token = token
    mail(to: @user.email, subject: 'Confirmez votre adresse électronique')
  end

  def invite_instructeur(user, reset_password_token)
    @reset_password_token = reset_password_token
    @user = user
    subject = "Activez votre compte instructeur"

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: subject,
      reply_to: CONTACT_EMAIL)
  end

  def invite_tiers(user, token, dossier)
    @token = token
    @user = user
    @dossier = dossier
    subject = "Vérification de votre adresse électronique"

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: subject,
      reply_to: CONTACT_EMAIL)
  end

  def resend_confirmation_email(user, token)
    @token = token
    @user = user
    subject = "Vérification de votre adresse électronique"

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: subject,
      reply_to: CONTACT_EMAIL)
  end

  def invite_gestionnaire(user, reset_password_token, groupe_gestionnaire)
    @reset_password_token = reset_password_token
    @user = user
    @groupe_gestionnaire = groupe_gestionnaire
    subject = "Activez votre compte gestionnaire"

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: subject,
      reply_to: CONTACT_EMAIL)
  end

  def send_archive(administrateur_or_instructeur, procedure, archive)
    @archive = archive
    @procedure = procedure
    @archive_url = case administrateur_or_instructeur
    when Instructeur then instructeur_archives_url(@procedure)
    when Administrateur then admin_procedure_archives_url(@procedure)
    else raise ArgumentError("send_archive expect either an Instructeur or an Administrateur")
    end
    @procedure_url = case administrateur_or_instructeur
    when Instructeur then instructeur_procedure_url(@procedure.id)
    when Administrateur then admin_procedure_url(@procedure)
    else raise ArgumentError("send_archive expect either an Instructeur or an Administrateur")
    end
    subject = "Votre archive est disponible"

    mail(to: administrateur_or_instructeur.email, subject: subject)
  end

  def notify_inactive_close_to_deletion(user)
    @user = user
    @subject = "Votre compte sera supprimé dans #{Expired::REMAINING_WEEKS_BEFORE_EXPIRATION} semaines"

    mail(to: user.email, subject: @subject)
  end

  def notify_after_closing(user, content, procedure = nil)
    @user = user
    @subject = "Clôture d’une démarche sur #{APPLICATION_NAME}"
    @procedure = procedure
    @content = content

    mail(to: user.email, subject: @subject, content: @content, procedure: @procedure)
  end

  def self.critical_email?(action_name)
    [
      'france_connect_merge_confirmation',
      "new_account_warning",
      "ask_for_merge",
      "invite_instructeur",
      "custom_confirmation_instructions",
    ].include?(action_name)
  end
end
