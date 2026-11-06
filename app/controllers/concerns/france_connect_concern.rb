# frozen_string_literal: true

module FranceConnectConcern
  extend ActiveSupport::Concern

  # In the user's Warden session, so it dies with the sign in it was set for
  FRANCE_CONNECT_PLUS_SESSION_KEY = 'france_connect_plus'

  def logged_in_with_france_connect?
    cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME].present? ||
      cookies.encrypted[FranceConnectPlusController::ID_TOKEN_COOKIE_NAME].present?
  end

  def logged_in_with_france_connect_plus?
    user_signed_in? && warden.session(:user)[FRANCE_CONNECT_PLUS_SESSION_KEY] == true
  end

  def france_connect_logout_url(callback:)
    id_token = cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME]
    plus_id_token = cookies.encrypted[FranceConnectPlusController::ID_TOKEN_COOKIE_NAME]
    state = cookies.encrypted[FranceConnectController::STATE_COOKIE_NAME]

    delete_france_connect_cookies

    if plus_id_token.present?
      FranceConnectPlusService.logout_url(id_token: plus_id_token, state:, callback:)
    else
      FranceConnectService.logout_url(id_token:, state:, callback:)
    end
  end

  def delete_france_connect_cookies
    cookies.delete(FranceConnectController::ID_TOKEN_COOKIE_NAME)
    cookies.delete(FranceConnectPlusController::ID_TOKEN_COOKIE_NAME)
    cookies.delete(FranceConnectController::STATE_COOKIE_NAME)
  end
end
