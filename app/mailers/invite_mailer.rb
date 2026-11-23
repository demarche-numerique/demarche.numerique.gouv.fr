# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/invite_mailer
class InviteMailer < ApplicationMailer
  layout 'mailers/layout'

  def invite_user(invite)
    use_recipient_locale(invite.user)
    bypass_unverified_mail_protection!

    @subject = default_i18n_subject
    targeted_user_link = invite.targeted_user_link || invite.create_targeted_user_link(target_context: 'invite',
                                                                                       target_model: invite,
                                                                                       user: invite.user)
    @url = targeted_user_link_url(targeted_user_link)
    if invite.user.present?
      send_mail(invite, invite.email_sender)
    end
  end

  def invite_guest(invite)
    bypass_unverified_mail_protection!

    @subject = default_i18n_subject(email_sender: invite.email_sender)
    targeted_user_link = invite.targeted_user_link || invite.create_targeted_user_link(target_context: 'invite',
                                                                                       target_model: invite)
    @url = targeted_user_link_url(targeted_user_link)

    send_mail(invite, invite.email_sender)
  end

  private

  def send_mail(invite, reply_to)
    @invite = invite
    email = invite.email

    mail(to: email,
      subject: @subject,
      reply_to: reply_to)
  end

  def self.critical_email?(action_name)
    true
  end
end
