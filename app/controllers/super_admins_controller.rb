# frozen_string_literal: true

class SuperAdminsController < ApplicationController
  before_action :authenticate_super_admin!

  def nav_bar_profile = :superadmin

  def edit_otp
  end

  def enable_otp
    if !current_super_admin.valid_password?(params[:current_password].to_s)
      flash[:alert] = "Mot de passe incorrect."
      redirect_to(edit_super_admin_otp_path) and return
    end

    if current_super_admin.otp_required_for_login? && !current_super_admin.validate_and_consume_otp!(params[:otp_attempt].to_s)
      flash[:alert] = "Code OTP invalide ou manquant."
      redirect_to(edit_super_admin_otp_path) and return
    end

    current_super_admin.enable_otp!
    @qrcode = generate_qr_code
    sign_out :super_admin
  end

  protected

  def authenticate_super_admin!
    if !super_admin_signed_in?
      redirect_to root_path
    end
  end

  private

  def generate_qr_code
    issuer = 'DSManager'

    if Rails.env.development?
      issuer += " (local)"
    elsif helpers.staging?
      issuer += " (dev)"
    end

    label = "#{issuer}:#{current_super_admin.email}"
    RQRCode::QRCode.new(current_super_admin.otp_provisioning_uri(label, issuer: issuer))
  end
end
