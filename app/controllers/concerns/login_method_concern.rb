# frozen_string_literal: true

# How the current user signed in, read from the row of their session: a cookie
# can outlive the session it describes, or miss the one it should.
module LoginMethodConcern
  extend ActiveSupport::Concern

  included do
    helper_method :logged_in_with_france_connect?, :logged_in_with_pro_connect?
  end

  def logged_in_with_france_connect? = current_login_method == 'france_connect'

  def logged_in_with_pro_connect? = current_login_method == 'pro_connect'

  private

  def current_login_method
    return if !user_signed_in?

    SessionRegistrableConcern.current(warden, :user)&.login_method || legacy_login_method
  end

  # Sessions opened before their row recorded how, read the way they used to be.
  # To delete once `UserSession.usable.where(login_method: nil)` is empty.
  def legacy_login_method
    if pro_connect_session.present?
      'pro_connect'
    elsif current_user.loged_in_with_france_connect.present?
      'france_connect'
    end
  end
end
