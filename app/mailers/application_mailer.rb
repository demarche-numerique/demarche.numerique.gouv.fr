# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  include MailerMonitoringConcern
  include PriorityDeliveryConcern

  helper MailerHelper

  helper :application # gives access to all helpers defined within `application_helper`.
  default from: "#{APPLICATION_NAME} <#{CONTACT_EMAIL}>"
  layout 'mailers/layout'

  before_action -> { Sentry.set_tags(mailer: mailer_name, action: action_name) }
end
