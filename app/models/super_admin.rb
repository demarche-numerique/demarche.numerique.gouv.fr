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
  #
  # unlock_strategy :none: a locked account stays locked, neither time nor an
  # email link lifts it. Unlock it from a console: SuperAdmin.find(id).unlock_access!
  devise :trackable, :validatable, :lockable, :recoverable, unlock_strategy: :none
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

  def verify_step_up_otp!(code)
    return :invalid if code.blank?

    with_attempt_limit { validate_and_consume_otp!(code) }
  end

  def verify_otp_enrollment!(password:, otp:)
    return :invalid if password.blank? || (otp_required_for_login? && otp.blank?)

    with_attempt_limit do
      valid_password?(password) && (!otp_required_for_login? || validate_and_consume_otp!(otp))
    end
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

  private

  # Returns :ok, :invalid or :locked. The attempt is counted before the
  # credentials are checked: concurrent requests each take a slot, so fewer than
  # maximum_attempts guesses are ever tested before the account locks.
  def with_attempt_limit
    increment_failed_attempts
    if attempts_exceeded?
      lock_access! unless access_locked?
      return :locked
    end

    return :invalid unless yield

    reset_failed_attempts!
    :ok
  end
end
