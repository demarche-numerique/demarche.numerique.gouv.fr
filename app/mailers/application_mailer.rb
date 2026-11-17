# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  include MailerMonitoringConcern
  include PriorityDeliveryConcern

  helper MailerHelper

  helper :application # gives access to all helpers defined within `application_helper`.
  default from: "#{APPLICATION_NAME} <#{CONTACT_EMAIL}>"
  layout 'mailers/layout'

  # deliver_later replays the locale of the request that enqueued the email, i.e. the sender's.
  # Render in the default locale instead, unless the action calls use_recipient_locale.
  around_action :with_default_locale
  before_action -> { Sentry.set_tags(mailer: mailer_name, action: action_name) }

  private

  def with_default_locale(&) = I18n.with_locale(I18n.default_locale, &)

  def use_recipient_locale(user)
    I18n.locale = user&.locale || I18n.default_locale
  end
end
