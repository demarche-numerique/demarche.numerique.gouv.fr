# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include TrustedDeviceConcern
  include NavBarProfileConcern
  include Pundit::Authorization
  include Devise::StoreLocationExtension
  include ApplicationController::ErrorHandling
  include ProConnectSessionConcern

  MAINTENANCE_MESSAGE = 'Le site est actuellement en maintenance. Il sera à nouveau disponible dans un court instant.'

  protect_from_forgery with: :exception, store: :cookie # define same store in config/initializers/active_storage.rb

  before_action :set_sentry_user
  before_action :redirect_if_untrusted
  before_action :reject, if: -> { ENV.fetch("MAINTENANCE_MODE", 'false') == 'true' }
  before_action :configure_permitted_parameters, if: :devise_controller?

  before_action :staging_authenticate
  before_action :set_active_storage_host
  before_action :setup_javascript_settings
  before_action :setup_tracking
  before_action :set_customizable_view_path
  before_action :display_csrf_retry_message

  around_action :switch_locale

  helper_method :multiple_devise_profile_connect?, :instructeur_signed_in?, :current_instructeur, :current_expert, :expert_signed_in?,
    :administrateur_signed_in?, :current_administrateur, :current_account, :localization_enabled?, :set_locale, :current_expert_not_instructeur?,
    :gestionnaire_signed_in?, :current_gestionnaire, :extra_query_params, :chatbot_disabled_page?

  before_action do
    Current.request_id = request.uuid
    Current.user = current_user
    Current.browser = browser
    # TODO: remove this block when migration to new domain is done
    Current.host = request.host_with_port

    Current.application_name = APPLICATION_NAME
    Current.contact_email = CONTACT_EMAIL
    Current.application_base_url = APPLICATION_BASE_URL
  end

  def staging_authenticate
    # FranceConnect sector identifier system does not support basic auth
    return if request.path == france_connect_redirect_uris_path

    if StagingAuthService.enabled? && !authenticate_with_http_basic { |username, password| StagingAuthService.authenticate(username, password) }
      request_http_basic_authentication
    end
  end

  def multiple_devise_profile_connect?
    user_signed_in? && instructeur_signed_in? ||
        instructeur_signed_in? && administrateur_signed_in? ||
        instructeur_signed_in? && gestionnaire_signed_in? ||
        instructeur_signed_in? && expert_signed_in? ||
        user_signed_in? && administrateur_signed_in? ||
        user_signed_in? && gestionnaire_signed_in? ||
        user_signed_in? && expert_signed_in? ||
        administrateur_signed_in? && gestionnaire_signed_in?
  end

  def current_instructeur
    current_user&.instructeur
  end

  def instructeur_signed_in?
    user_signed_in? && current_user&.instructeur.present?
  end

  def current_administrateur
    current_user&.administrateur
  end

  def administrateur_signed_in?
    current_administrateur.present?
  end

  def current_gestionnaire
    current_user&.gestionnaire
  end

  def gestionnaire_signed_in?
    current_gestionnaire.present?
  end

  def current_expert
    current_user&.expert
  end

  def current_expert_not_instructeur?
    current_user&.expert? && !current_user&.instructeur?
  end

  def expert_signed_in?
    current_expert.present?
  end

  def current_account
    {
      gestionnaire: current_gestionnaire,
      administrateur: current_administrateur,
      instructeur: current_instructeur,
      expert: current_expert,
      user: current_user,
    }.compact
  end

  alias_method :pundit_user, :current_account

  def localization_enabled?
    ENV.fetch('LOCALIZATION_ENABLED', 'false') == 'true' || cookies[:locale].present? || !browser_prefers_french?
  end

  def browser_prefers_french?
    http_accept_language.compatible_language_from(I18n.available_locales) == 'fr'
  end

  def set_locale(locale)
    return if !locale.respond_to?(:to_sym)

    if locale.to_sym.in?(I18n.available_locales)
      cookies[:locale] = { value: locale, secure: Rails.env.production?, httponly: true }
      if user_signed_in?
        current_user.update(locale: locale)
      end
      locale
    end
  end

  def ajax_redirect(path)
    "window.location.href='#{path}'"
  end

  def message_encryptor_service
    @message_encryptor_service ||= MessageEncryptorService.new
  end

  protected

  def feature_enabled?(feature_name)
    Flipper.enabled?(feature_name, current_user)
  end

  private

  def display_csrf_retry_message
    return unless params[:csrf_retry] == '1'

    flash.now[:alert] = I18n.t('errors.csrf_retry.message')
  end

  def authenticate_logged_user!
    if instructeur_signed_in?
      authenticate_instructeur!
    elsif expert_signed_in?
      authenticate_expert!
    elsif administrateur_signed_in?
      authenticate_administrateur!
    elsif gestionnaire_signed_in?
      authenticate_gestionnaire!
    else
      authenticate_user!
    end
  end

  def authenticate_instructeur!
    if !instructeur_signed_in?
      store_location_for(:user, request.fullpath)
      redirect_to new_user_session_path
    end
  end

  def authenticate_expert!
    if !expert_signed_in?
      store_location_for(:user, request.fullpath)
      redirect_to new_user_session_path
    end
  end

  def authenticate_instructeur_or_expert!
    if !instructeur_signed_in? && !expert_signed_in?
      store_location_for(:user, request.fullpath)
      redirect_to new_user_session_path
    end
  end

  def authenticate_administrateur!
    if !administrateur_signed_in?
      store_location_for(:user, request.fullpath)
      redirect_to new_user_session_path
    end
  end

  def authenticate_gestionnaire!
    if !gestionnaire_signed_in?
      redirect_to new_user_session_path
    end
  end

  def after_sign_out_path_for(_resource_or_scope)
    stored_location_for(:user) || super
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [:otp_attempt])
  end

  private

  def set_active_storage_host
    ActiveStorage::Current.url_options ||= {}
    ActiveStorage::Current.url_options[:host] = request.base_url
  end

  def setup_javascript_settings
    gon.autosave = Rails.application.config.ds_autosave
    gon.autocomplete = {
      api_geo_url: API_GEO_URL,
      api_adresse_url: API_ADRESSE_URL,
      api_education_url: API_EDUCATION_URL,
    }
  end

  def setup_tracking
    gon.matomo = matomo_config
    gon.sentry = sentry_config

    if !chatbot_disabled_page? && user_signed_in?
      gon.crisp = crisp_config
    end
  end

  CHATBOT_DISABLED_PAGES = [
    ['users/dossiers', 'brouillon'],
    ['users/dossiers', 'modifier'],
  ].freeze

  def chatbot_disabled_page?
    CHATBOT_DISABLED_PAGES.include?([controller_path, action_name])
  end

  def current_user_roles
    @current_user_roles ||= begin
      roles = [
        current_user,
        current_instructeur,
        current_expert,
        current_administrateur,
        current_gestionnaire,
        current_super_admin,
      ].compact.map { |role| role.class.name }

      roles.any? ? roles.join(', ') : 'Guest'
    end
  end

  def set_sentry_user
    Sentry.set_user(sentry_user)
  end

  def set_sentry_dossier(dossier)
    Sentry.configure_scope do |scope|
      scope.set_tags(procedure: dossier.procedure.id)
      scope.set_tags(dossier: dossier.id)
    end
  end

  # private method called by rails fwk
  # see https://github.com/roidrage/lograge
  def append_info_to_payload(payload)
    super

    payload[:to_log] = {}
    request_logs(payload[:to_log])
  end

  def request_logs(logs)
    logs.merge!({
      user_agent: request.user_agent,
      user_id: current_user&.id,
      user_roles: current_user_roles,
      client_ip: request.remote_ip,
      request_id: Current.request_id,
    })

    if browser.known?
      logs.merge!({
        browser: browser.name,
        browser_version: browser.version.to_s,
        platform: browser.platform.name,
      })
    end
  end

  def reject
    authorized_request =
      request.path_info == '/' ||
      request.path_info.start_with?('/manager') ||
      request.path_info.start_with?('/super_admins')

    api_request = request.path_info.start_with?('/api/')

    if super_admin_signed_in? || authorized_request
      flash.now.alert = MAINTENANCE_MESSAGE
    elsif api_request
      render json: { error: MAINTENANCE_MESSAGE }.to_json, status: :service_unavailable
    else
      [:user, :instructeur, :administrateur].each { |role| sign_out(role) }
      flash[:alert] = MAINTENANCE_MESSAGE
      redirect_to root_path
    end
  end

  def redirect_if_untrusted
    if instructeur_signed_in? &&
        sensitive_path &&
        !current_instructeur.bypass_email_login_token &&
        !IPService.ip_trusted?(request.remote_ip) &&
        !trusted_device? &&
        !pro_connect_mfa?

      # return at this location
      # after the device is trusted
      if get_stored_location_for(:user).blank?
        store_location_for(:user, request.fullpath)
      end

      send_login_token_or_bufferize(current_instructeur)
      signed_email = message_encryptor_service.encrypt_and_sign(current_instructeur.email, purpose: :reset_link, expires_in: 1.hour)
      redirect_to link_sent_path(email: signed_email)
    end
  end

  def sensitive_path
    path = request.path_info

    if path == '/' ||
      path == '/users/sign_out' ||
      path == '/contact' ||
      path == '/contact-admin' ||
      path.start_with?('/connexion-par-jeton') ||
      path.start_with?('/api/') ||
      path.start_with?('/lien-envoye') ||
      path.start_with?('/faq')

      false
    else
      true
    end
  end

  def sentry_user
    if user_signed_in?
      { id: "User##{current_user.id}" }
    elsif administrateur_signed_in?
      { id: "Administrateur##{current_administrateur.id}" }
    else
      { id: 'Guest' }
    end
  end

  def sentry_config
    {
      key: ENV["SENTRY_DSN_JS"],
      enabled: ENV.enabled?("SENTRY"),
      environment: ENV["SENTRY_CURRENT_ENV"],
      browser: { modern: BrowserSupport.supported?(browser) },
      user: sentry_user,
      release: ApplicationVersion.current,
    }
  end

  def matomo_config
    {
      cookieDomain: ENV['MATOMO_COOKIE_DOMAIN'],
      domain: ENV['MATOMO_DOMAIN'],
      enabled: ENV.enabled?('MATOMO'),
      host: ENV['MATOMO_HOST'],
      key: ENV['MATOMO_ID'],
    }.compact
  end

  def crisp_config
    enabled = ENV.enabled?("CRISP")

    {
      enabled:,
      websiteId: enabled ? ENV.fetch("CRISP_WEBSITE_ID") : nil,
      user: {
        email: current_user&.email,
        emailSignature: crisp_email_signature,
        segments: crisp_segments,
      },
    }
  end

  def crisp_email_signature
    key = ENV["CRISP_IDENTITY_PRIVATE_KEY"]
    return if key.blank?

    return unless current_user&.email_verified_at?

    OpenSSL::HMAC.hexdigest("sha256", key, current_user.email)
  end

  def crisp_segments
    current_user&.crisp_segments
  end

  def current_email
    current_user&.email
  end

  def switch_locale(&action)
    unchecked_locale = extract_locale_from_query_params ||
      extract_locale_from_cookie ||
      extract_locale_from_user ||
      extract_locale_from_accept_language_header ||
      I18n.default_locale

    locale = unchecked_locale.to_sym.in?(I18n.available_locales) ? unchecked_locale : I18n.default_locale

    gon.locale = locale

    I18n.with_locale(locale, &action)
  end

  def extract_locale_from_query_params
    set_locale(request.query_parameters[:locale])
  end

  def extract_locale_from_user
    current_user&.locale
  end

  def extract_locale_from_cookie
    cookies[:locale]
  end

  def extract_locale_from_accept_language_header
    if localization_enabled?
      http_accept_language.compatible_language_from(I18n.available_locales)
    end
  end

  def set_customizable_view_path
    prepend_view_path "app/custom_views"
  end

  def cast_bool(value)
    ActiveRecord::Type::Boolean.new.deserialize(value)
  end
end
