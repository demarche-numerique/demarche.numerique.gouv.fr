# frozen_string_literal: true

module ProConnectSessionConcern
  extend ActiveSupport::Concern

  SESSION_INFO_COOKIE_NAME = :pro_connect_session_info
  ADMINISTRATEUR_DEVICE_COOKIE_NAME = :administrateur_device

  included do
    helper_method :logged_in_with_pro_connect?, :pro_connect_only_login?
  end

  def set_pro_connect_session_info_cookie(user_id, mfa: false)
    value = { user_id:, mfa:, mfa_at: Time.current.iso8601 }.to_json
    cookies.encrypted[SESSION_INFO_COOKIE_NAME] = {
      value:,
      expires: TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD.from_now,
      secure: Rails.env.production?,
      httponly: true,
    }
  end

  def logged_in_with_pro_connect?
    pro_connect_session.present?
  end

  def pro_connect_mfa?
    info = pro_connect_session
    return false if info['mfa'] != true || info['mfa_at'].blank?

    Time.iso8601(info['mfa_at']) > TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD.ago
  end

  def delete_pro_connect_session_info_cookie
    cookies.delete SESSION_INFO_COOKIE_NAME
  end

  def remember_administrateur_device
    cookies[ADMINISTRATEUR_DEVICE_COOKIE_NAME] = {
      value: '1',
      expires: 1.year.from_now,
      secure: Rails.env.production?,
      httponly: true,
    }
  end

  def forget_administrateur_device
    cookies.delete ADMINISTRATEUR_DEVICE_COOKIE_NAME
  end

  def pro_connect_only_login?
    params[:force_pro_connect].present? ||
      (cookies[ADMINISTRATEUR_DEVICE_COOKIE_NAME].present? && params[:particulier].blank?)
  end

  def redirect_to_pro_connect_required
    redirect_to pro_connect_path(force_pro_connect: true), alert: t('errors.messages.pro_connect.required')
  end

  private

  def pro_connect_session
    session = if cookies.encrypted[SESSION_INFO_COOKIE_NAME].present?
      JSON.parse(cookies.encrypted[SESSION_INFO_COOKIE_NAME])
    else
      {}
    end

    session['user_id'] == current_user.id ? session : {}
  end
end
