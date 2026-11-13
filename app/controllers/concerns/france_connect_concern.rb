# frozen_string_literal: true

module FranceConnectConcern
  extend ActiveSupport::Concern

  # Whether a provider session is left to close on sign out: the user may be
  # signed out already, and the logout url needs the id token anyway.
  def france_connect_id_token?
    cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME].present? ||
      cookies.encrypted[FranceConnectPlusController::ID_TOKEN_COOKIE_NAME].present?
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
