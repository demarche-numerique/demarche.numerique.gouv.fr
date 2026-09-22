# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  include DevisePopulatedResource

  # Declared first so it runs last: after_action callbacks run in reverse.
  after_action :trust_device_after_reset, only: [:update]
  after_action :try_to_authenticate_instructeur, only: [:update]
  after_action :try_to_authenticate_administrateur, only: [:update]
  after_action :update_email_verified_at, only: [:update]

  # GET /resource/password/new
  # def new
  #   super
  # end

  # POST /resource/password
  # def create
  #   super
  # end

  # GET /resource/password/edit?reset_password_token=abcdef
  def edit
    user = User.with_reset_password_token(params[:reset_password_token])
    return redirect_to_pro_connect_required if user&.administrateur&.pro_connect_required?

    super
  end

  # PUT /resource/password
  def update
    user = User.with_reset_password_token(resource_params[:reset_password_token])

    return redirect_to_pro_connect_required if user&.administrateur&.pro_connect_required?

    super
  end

  def reset_link_sent
    @email = message_encryptor_service.decrypt_and_verify(params[:email], purpose: :reset_password) rescue nil
  end

  protected

  # def after_resetting_password_path_for(resource)
  #   super(resource)
  # end

  def after_sending_reset_password_instructions_path_for(resource_name)
    flash.discard(:notice)
    signed_email = message_encryptor_service.encrypt_and_sign(resource.email, purpose: :reset_password, expires_in: 1.hour)
    users_password_reset_link_sent_path(email: signed_email)
  end

  def try_to_authenticate_instructeur
    if user_signed_in?
      instructeur = Instructeur.by_email(current_user.email)

      if instructeur
        sign_in(instructeur.user)
      end
    end
  end

  def try_to_authenticate_administrateur
    if user_signed_in?
      administrateur = Administrateur.by_email(current_user.email)

      if administrateur
        sign_in(administrateur.user)
      end
    end
  end

  # The reset link arrived by email, which is the proof `trusted_device?` asks
  # for. The password change bumped `trusted_device_version`, so without this
  # the instructeur would be sent a second link to prove what the first proved.
  # Users::ActivateController#create does the same.
  def trust_device_after_reset
    return if !user_signed_in?
    return if current_user.instructeur.nil?

    trust_device(Time.zone.now, current_user.instructeur)
  end

  def update_email_verified_at
    if user_signed_in?
      current_user.update!(email_verified_at: Time.zone.now)
    end
  end
end
