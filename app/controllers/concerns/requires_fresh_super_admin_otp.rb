# frozen_string_literal: true

module RequiresFreshSuperAdminOtp
  extend ActiveSupport::Concern

  protected

  def verify_fresh_super_admin_otp!
    return unless SUPER_ADMIN_OTP_ENABLED

    code = params[:otp_attempt].to_s.strip
    return if code.present? && current_super_admin.validate_and_consume_otp!(code)

    flash[:error] = t("manager.fresh_otp.invalid_code")
    redirect_back_or_to(manager_root_path)
  end
end
