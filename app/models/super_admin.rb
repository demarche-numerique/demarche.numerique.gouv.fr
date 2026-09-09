# frozen_string_literal: true

class SuperAdmin < ApplicationRecord
  include PasswordComplexityConcern
  include SessionRegistrableConcern

  # Left over from :rememberable. Ignored here first, dropped in a later
  # migration: a column removed while running code still selects it breaks
  # every query in the window between migration and deploy.
  self.ignored_columns += [:remember_created_at]

  # No :rememberable, it would make the daily deadline below a fiction: on the
  # 25th hour the cookie reopens the session for another day.
  devise :trackable, :validatable, :lockable, :recoverable
  if SUPER_ADMIN_OTP_ENABLED
    devise :two_factor_authenticatable, sign_in_after_reset_password: false
  else
    devise :database_authenticatable
  end

  def session_max_lifetime = 24.hours

  def enable_otp!
    self.otp_secret = SuperAdmin.generate_otp_secret
    self.consumed_timestep = nil
    self.otp_required_for_login = true
    save!
  end

  def disable_otp!
    self.assign_attributes(
      {
        otp_secret: nil,
        consumed_timestep: nil,
        otp_required_for_login: false,
      }
    )
    save!
  end

  def invite_admin(email)
    user = User.create_or_promote_to_administrateur(email, SecureRandom.hex)

    if user.valid?
      user.invite_administrateur!
      Procedure.create_initiation_procedure(user.administrateur)
    end

    user
  end

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end
end
