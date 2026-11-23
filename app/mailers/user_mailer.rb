# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailer < ApplicationMailer
  layout 'mailers/layout'

  def new_account_warning(user, procedure = nil)
    use_recipient_locale(user, requested_by_recipient: true)
    @user = user
    @subject = default_i18n_subject
    @procedure = procedure

    mail(to: user.email, subject: @subject, procedure: @procedure)
  end

  def ask_for_merge(user, requested_email)
    use_recipient_locale(requested_email)
    @user = user
    @requested_email = requested_email
    @subject = default_i18n_subject

    mail(to: requested_email, subject: @subject)
  end

  def france_connect_merge_confirmation(email, email_merge_token, email_merge_token_created_at)
    use_recipient_locale(email, requested_by_recipient: true)
    @email_merge_token = email_merge_token
    @email_merge_token_created_at = email_merge_token_created_at
    @subject = default_i18n_subject

    mail(to: email, subject: @subject)
  end

  def custom_confirmation_instructions(user, token)
    use_recipient_locale(user, requested_by_recipient: true)
    @user = user

    @token = token
    mail(to: @user.email, subject: default_i18n_subject)
  end

  def invite_instructeur(user, reset_password_token)
    use_recipient_locale(user)
    @reset_password_token = reset_password_token
    @user = user
    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: default_i18n_subject,
      reply_to: CONTACT_EMAIL)
  end

  def invite_tiers(user, token, dossier)
    use_recipient_locale(user)
    @token = token
    @user = user
    @dossier = dossier

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: default_i18n_subject,
      reply_to: CONTACT_EMAIL)
  end

  def resend_confirmation_email(user, token)
    use_recipient_locale(user, requested_by_recipient: true)
    @token = token
    @user = user

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: default_i18n_subject,
      reply_to: CONTACT_EMAIL)
  end

  def invite_gestionnaire(user, reset_password_token, groupe_gestionnaire)
    use_recipient_locale(user)
    @reset_password_token = reset_password_token
    @user = user
    @groupe_gestionnaire = groupe_gestionnaire

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: default_i18n_subject,
      reply_to: CONTACT_EMAIL)
  end

  def invite_gestionnaire_via_pro_connect(user, groupe_gestionnaire)
    use_recipient_locale(user)
    @user = user
    @groupe_gestionnaire = groupe_gestionnaire

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: default_i18n_subject,
      reply_to: CONTACT_EMAIL)
  end

  def reset_password_via_pro_connect(user)
    use_recipient_locale(user, requested_by_recipient: true)
    @user = user

    bypass_unverified_mail_protection!

    mail(to: user.email,
      subject: default_i18n_subject,
      reply_to: CONTACT_EMAIL)
  end

  def send_archive(administrateur_or_instructeur, procedure, archive)
    use_recipient_locale(administrateur_or_instructeur.user)
    @archive = archive
    @procedure = procedure
    @archive_url = case administrateur_or_instructeur
    when Instructeur then list_instructeur_archives_url(@procedure)
    when Administrateur then admin_procedure_archives_url(@procedure)
    else raise ArgumentError("send_archive expect either an Instructeur or an Administrateur")
    end
    @procedure_url = case administrateur_or_instructeur
    when Instructeur then instructeur_procedure_url(@procedure.id)
    when Administrateur then admin_procedure_url(@procedure)
    else raise ArgumentError("send_archive expect either an Instructeur or an Administrateur")
    end
    mail(to: administrateur_or_instructeur.email, subject: default_i18n_subject)
  end

  def notify_inactive_close_to_deletion(user)
    use_recipient_locale(user)
    @user = user
    @subject = default_i18n_subject(remaining_weeks: Expired::REMAINING_WEEKS_BEFORE_EXPIRATION, application_name: APPLICATION_NAME)

    mail(to: user.email, subject: @subject)
  end

  def notify_after_closing(user, content, procedure = nil)
    use_recipient_locale(user)
    @user = user
    @subject = default_i18n_subject(application_name: APPLICATION_NAME)
    @procedure = procedure
    @content = content

    mail(to: user.email, subject: @subject, content: @content, procedure: @procedure)
  end

  def account_reactivated(user)
    use_recipient_locale(user)
    @user = user
    @subject = default_i18n_subject

    mail(to: user.email, subject: @subject)
  end

  def password_changed(user)
    use_recipient_locale(user, requested_by_recipient: true)
    @user = user
    @subject = default_i18n_subject

    mail(to: user.email, subject: @subject)
  end

  def self.critical_email?(action_name)
    [
      'france_connect_merge_confirmation',
      "new_account_warning",
      "ask_for_merge",
      "invite_instructeur",
      "invite_tiers",
      "resend_confirmation_email",
      "custom_confirmation_instructions",
      "reset_password_via_pro_connect",
      "password_changed",
    ].include?(action_name)
  end
end
