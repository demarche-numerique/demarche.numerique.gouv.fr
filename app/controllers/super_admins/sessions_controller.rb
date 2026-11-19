# frozen_string_literal: true

class SuperAdmins::SessionsController < Devise::SessionsController
  def nav_bar_profile = :superadmin

  private

  # Devise permits remember_me for every scope, but SuperAdmin is not rememberable:
  # a failed attempt carrying it would crash rebuilding the sign in form.
  def sign_in_params = super.except(:remember_me)

  def request_logs(logs)
    super

    if action_name == "create" && logs[:super_admin_id].nil?
      super_admin = SuperAdmin.find_for_authentication(email: sign_in_params[:email])
      logs[:super_admin_id] = super_admin&.id
      logs[:failed_attempt] = super_admin&.access_locked? ? "locked" : "invalid"
    end
  end
end
