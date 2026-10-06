# frozen_string_literal: true

class SuperAdmins::SessionsController < Devise::SessionsController
  def nav_bar_profile = :superadmin

  private

  def request_logs(logs)
    super

    if action_name == "create"
      logs[:super_admin_id] ||= SuperAdmin.find_for_authentication(email: sign_in_params[:email])&.id
    end
  end
end
