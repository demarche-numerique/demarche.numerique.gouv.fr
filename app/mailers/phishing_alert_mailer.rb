# frozen_string_literal: true

class PhishingAlertMailer < ApplicationMailer
  layout 'mailers/layout'

  def notify(user)
    use_recipient_locale(user)
    @user = user
    @subject = default_i18n_subject

    mail(to: user.email, subject: @subject)
  end

  def self.critical_email?(action_name) = false
end
