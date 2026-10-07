# frozen_string_literal: true

module RequiresFreshSuperAdminOtp
  extend ActiveSupport::Concern

  private

  def verify_fresh_super_admin_otp!
    return unless SUPER_ADMIN_OTP_ENABLED

    result = current_super_admin.verify_step_up_otp!(params[:otp_attempt].to_s)
    return if result == :ok

    reject_super_admin_attempt!(result) do
      flash[:error] = t("manager.fresh_otp.invalid_code")
      redirect_back_or_to(manager_root_path)
    end
  end

  # Reacts to a failed SuperAdmin credential check (see SuperAdmin#with_attempt_limit):
  # signs a locked account out, or yields to the caller otherwise.
  def reject_super_admin_attempt!(result)
    # Kept for the logs: on a lockout, sign_out below empties current_super_admin.
    @rejected_super_admin_attempt = { super_admin_id: current_super_admin.id, failed_attempt: result.to_s }

    return yield unless result == :locked

    Sentry.set_tags(super_admin: current_super_admin.id)
    Sentry.capture_message("Super admin locked after too many failed attempts", extra: { action: "#{controller_path}##{action_name}" })

    sign_out(:super_admin)
    flash[:error] = t("super_admins.lockout.locked")
    redirect_to new_super_admin_session_path
  end

  def append_info_to_payload(payload)
    super

    payload[:to_log].merge!(@rejected_super_admin_attempt) if @rejected_super_admin_attempt
  end
end
