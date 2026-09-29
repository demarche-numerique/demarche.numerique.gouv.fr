# frozen_string_literal: true

# Turbo Drive refuses a page rendered with a 200 in answer to a form submission
# ("Form responses must redirect to another location"): nothing is displayed and
# the user stays on the form they submitted. An action answering anything but a
# GET must therefore redirect, render a turbo stream, or render with an error
# status: a form re-rendered with its validation errors is
# `render :edit, status: :unprocessable_content`.
#
# Every example fails on a response breaking that rule, so that the offending
# action is found by its controller spec rather than by a user.
module FormResponseGuard
  class PageRenderedError < StandardError
    def initialize(controller)
      action = "#{controller.controller_path}##{controller.action_name}"

      super(<<~MESSAGE.squish)
        #{action} answered a #{controller.request.request_method} with a page and a 200, which
        Turbo Drive does not render. Redirect, or render with `status: :unprocessable_content`
        (see spec/support/form_response_guard.rb).
      MESSAGE
    end
  end

  # Responses Turbo does accept, or never sees. Keep the reason next to the action.
  ALLOWED = [
    # submitted from inside a turbo-frame, which renders the response; the
    # controller specs do not send the Turbo-Frame header
    'administrateurs/api_tokens#update',
    'users/ami_consents#create',
    # the page displays a secret once and cannot be redirected to: the form
    # opts out of Turbo with data-turbo="false"
    'administrateurs/api_tokens#create',
    'super_admins#enable_otp',
    # asking for the password of an existing account is a step, not an error:
    # the email choice form opts out of Turbo with data-turbo="false"
    'france_connect#send_email_merge_request',
    # called by jQuery, not by a form
    'manager/users#enable_feature',
  ].freeze

  def process_action(*)
    super.tap { raise PageRenderedError, self if FormResponseGuard.page_rendered?(self) }
  end

  def self.page_rendered?(controller)
    request, response = controller.request, controller.response

    return false if request.get? || request.head?
    return false if response.status != 200 || response.media_type != 'text/html'
    return false if request.headers['Turbo-Frame'].present?
    # a failed sign in: Devise calls the form action back, then sets the error status itself
    return false if request.env['warden.options']&.key?(:recall)

    ALLOWED.exclude?("#{controller.controller_path}##{controller.action_name}")
  end
end

ActiveSupport.on_load(:action_controller) { prepend FormResponseGuard }
