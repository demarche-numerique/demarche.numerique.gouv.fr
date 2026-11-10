# frozen_string_literal: true

module FranceConnectConcern
  extend ActiveSupport::Concern

  # Whether a provider session is left to close on sign out: the user may be
  # signed out already, and the logout url needs the id token anyway.
  def france_connect_id_token?
    cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME].present?
  end

  def france_connect_logout_url(callback:)
    id_token = cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME]
    state = cookies.encrypted[FranceConnectController::STATE_COOKIE_NAME]

    cookies.delete(FranceConnectController::ID_TOKEN_COOKIE_NAME)
    cookies.delete(FranceConnectController::STATE_COOKIE_NAME)

    FranceConnectService.logout_url(id_token:, state:, callback:)
  end

  def delete_france_connect_cookies
    cookies.delete(FranceConnectController::ID_TOKEN_COOKIE_NAME)
    cookies.delete(FranceConnectController::STATE_COOKIE_NAME)
  end
end
