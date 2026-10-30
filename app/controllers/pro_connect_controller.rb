# frozen_string_literal: true

# doc: https://github.com/numerique-gouv/proconnect-documentation/tree/main
class ProConnectController < ApplicationController
  include ProConnectSessionConcern

  before_action :redirect_to_login_if_fc_aborted, only: [:callback]
  before_action :check_state, only: [:callback]

  MON_COMPTE_PRO_IDP_ID = "71144ab3-ee1a-4401-b7b3-79b44f7daeeb"

  STATE_COOKIE_NAME = :proConnect_state
  NONCE_COOKIE_NAME = :proConnect_nonce
  MFA_FORCED_COOKIE_NAME = :proConnect_mfa_forced

  def index
  end

  def required; end

  def login
    # A forced MFA round trip abandoned on the ProConnect screen never reaches
    # the callback, so its marker is still there.
    cookies.delete MFA_FORCED_COOKIE_NAME

    uri, state, nonce = ProConnectService.authorization_uri

    cookies.encrypted[STATE_COOKIE_NAME] = { value: state, secure: Rails.env.production?, httponly: true }
    cookies.encrypted[NONCE_COOKIE_NAME] = { value: nonce, secure: Rails.env.production?, httponly: true }

    redirect_to uri, allow_other_host: true
  end

  def callback
    user_info, id_token, amr, acr = ProConnectService.user_info(params[:code], cookies.encrypted[NONCE_COOKIE_NAME])
    cookies.delete NONCE_COOKIE_NAME

    email = santized_email(user_info)
    mfa = ProConnectService.mfa?(amr:, acr:)
    mfa_already_forced = cookies.encrypted[MFA_FORCED_COOKIE_NAME] == email
    cookies.delete MFA_FORCED_COOKIE_NAME

    user = User.find_by(email:)

    if user.nil?
      user = User.create!(
        email:,
        password: Devise.friendly_token[0, 20],
        confirmed_at: Time.current,
        email_verified_at: Time.current
      )
      user.after_confirmation
    else
      user.update!(email_verified_at: Time.current) if user.email_verified_at.nil?
    end

    ProConnectInformation.record!(user:, user_info:, amr:, acr:)

    remember_administrateur_device if user.administrateur&.pro_connect_required?

    return enforce_mfa(email, already_forced: mfa_already_forced) if !mfa && must_force_mfa?(user, user_info)

    sign_in_with_pro_connect(user, id_token:, mfa:)
    redirect_to stored_location_for(:user) || root_path

  rescue Rack::OAuth2::Client::Error => e
    Rails.logger.error e.message
    redirect_pro_connect_error_connection
  end

  private

  def santized_email(user_info)
    user_info['email'].strip.downcase
  end

  # Mon Compte Pro is the one identity provider known to offer a second factor.
  def must_force_mfa?(user, user_info)
    user.administrateur&.pro_connect_required? ||
      (user.instructeur? && user_info['idp_id'] == MON_COMPTE_PRO_IDP_ID)
  end

  def enforce_mfa(email, already_forced:)
    already_forced ? redirect_pro_connect_mfa_failed : redirect_to_forced_mfa(email)
  end

  def redirect_to_forced_mfa(email)
    uri, state, nonce = ProConnectService.authorization_uri(force_mfa: true, login_hint: email)

    cookies.encrypted[STATE_COOKIE_NAME] = { value: state, secure: Rails.env.production?, httponly: true }
    cookies.encrypted[NONCE_COOKIE_NAME] = { value: nonce, secure: Rails.env.production?, httponly: true }
    cookies.encrypted[MFA_FORCED_COOKIE_NAME] = { value: email, secure: Rails.env.production?, httponly: true }

    redirect_to uri, allow_other_host: true
  end

  def redirect_pro_connect_mfa_failed
    flash.alert = t('errors.messages.pro_connect.mfa_failed')
    redirect_to pro_connect_path
  end

  def redirect_to_login_if_fc_aborted
    if params[:code].blank?
      redirect_to new_user_session_path
    end
  end

  def redirect_pro_connect_error_connection
    flash.alert = t('errors.messages.pro_connect.connexion')
    redirect_to(new_user_session_path)
  end

  def check_state
    expected_state = cookies.encrypted[STATE_COOKIE_NAME]
    if expected_state.blank? || expected_state != params[:state]
      flash.alert = t('errors.messages.pro_connect.connexion')
      redirect_to(new_user_session_path)
    else
      cookies.delete STATE_COOKIE_NAME
    end
  end
end
