# frozen_string_literal: true

# Sessions opened before their row recorded how take it, once, from the cookie
# the provider left for this account.
# To delete, with its `before_action` in ApplicationController, once
# `UserSession.usable.where(login_method: nil)` is empty.
module LegacyLoginMethodConcern
  extend ActiveSupport::Concern

  private

  def record_legacy_login_method
    user_session = Current.user_session if user_signed_in?
    return if user_session.nil? || user_session.login_method.present?

    # Neither provider: a password, or the odd email link, read the same way.
    login_method =
      if pro_connect_session.present?
        :pro_connect
      elsif france_connect_session?
        :france_connect
      else
        :password
      end

    user_session.update_column(:login_method, login_method)
  end

  def france_connect_session?
    id_token = cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME]
    return false if id_token.blank?

    sub = JSON::JWT.decode(id_token, :skip_verification)['sub']
    current_user.france_connect_informations.exists?(france_connect_particulier_id: sub)
  rescue JSON::JWT::Exception
    false
  end
end
