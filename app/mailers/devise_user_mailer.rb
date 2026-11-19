# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/devise_user_mailer
class DeviseUserMailer < Devise::Mailer
  helper :application # gives access to all helpers defined within `application_helper`.
  helper MailerHelper
  include Devise::Controllers::UrlHelpers # Optional. eg. `confirmation_url`
  include MailerMonitoringConcern
  include PriorityDeliveryConcern

  layout 'mailers/layout'
  default from: "#{APPLICATION_NAME} <#{CONTACT_EMAIL}>"

  def template_paths
    ['devise_mailer']
  end

  def confirmation_instructions(record, token, opts_or_headers = {})
    opts_or_headers[:from] = NO_REPLY_EMAIL
    opts_or_headers[:reply_to] = NO_REPLY_EMAIL
    @procedure = opts_or_headers[:procedure_after_confirmation] || nil
    @prefill_token = opts_or_headers[:prefill_token]

    bypass_unverified_mail_protection!

    I18n.with_locale(record.locale) do
      if record.unconfirmed_email.nil?
        @subject = t('.subject', application_name: APPLICATION_NAME)
        opts_or_headers[:subject] = @subject
      end

      super
    end
  end

  def reset_password_instructions(record, token, opts = {})
    bypass_unverified_mail_protection!

    super
  end

  def self.critical_email?(action_name)
    true
  end
end
