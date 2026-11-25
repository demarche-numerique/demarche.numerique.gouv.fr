# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/administration_mailer
class AdministrationMailer < ApplicationMailer
  layout 'mailers/layout'

  def invite_admin(user, reset_password_token)
    @reset_password_token = reset_password_token
    @user = user
    @author_name = "Équipe de #{APPLICATION_NAME}"

    bypass_unverified_mail_protection!

    use_recipient_locale(user)

    mail(to: user.email,
      subject: default_i18n_subject,
      reply_to: CONTACT_EMAIL)
  end

  def invite_admin_via_pro_connect(user)
    @user = user
    @author_name = "Équipe de #{APPLICATION_NAME}"

    bypass_unverified_mail_protection!

    use_recipient_locale(user)

    mail(to: user.email,
      subject: default_i18n_subject,
      reply_to: CONTACT_EMAIL)
  end

  def self.critical_email?(action_name)
    action_name.in?(["invite_admin", "invite_admin_via_pro_connect"])
  end
end
