# frozen_string_literal: true

class SwitchDomainBannerComponent < ApplicationComponent
  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def render?
    return false unless helpers.switch_domain_enabled?(request)
    return false if requested_from_new_domain?

    true
  end

  def auto_switch?
    helpers.auto_switch_domain?(request, user.present?)
  end

  def manual_switch?
    helpers.app_host_legacy?(request) && user.present?
  end

  def new_host_url
    stored_location = helpers.get_stored_location_for(:user)

    # don't work on any controller
    # user was not signed on ds.fr,  ut may be signed on demarche.numerique.gouv
    return "//#{ApplicationHelper::APP_HOST}#{stored_location}" if stored_location.present?

    helpers.url_for(url_options)
  end

  def requested_from_new_domain?
    Current.host == ApplicationHelper::APP_HOST
  end

  private

  def url_options
    { params: request.query_parameters.except(:switch_domain) }.merge(host: ApplicationHelper::APP_HOST)
  end
end
