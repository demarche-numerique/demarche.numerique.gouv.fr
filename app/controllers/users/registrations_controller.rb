# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  include ProcedureContextConcern

  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]
  before_action :restore_procedure_context, only: [:new, :create]

  layout 'login', only: [:new, :create]

  # GET /resource/sign_up
  def new
    # Allow pre-filling the user email from a query parameter
    build_resource({ email: sign_up_params[:email] })

    if block_given?
      yield resource
    end

    respond_with resource
  end

  # POST /resource
  def create
    # We may need the confirmation mailer to access the current procedure.
    # But there's no easy way to pass an argument to the mailer through
    # all Devise code.
    # So instead we use a per-request global variable.
    CurrentConfirmation.procedure_after_confirmation = @procedure
    CurrentConfirmation.prefill_token = @prefill_token

    # Handle existing user trying to sign up again
    existing_user = user_email_param.present? ? User.find_by(email: user_email_param) : nil
    if existing_user.present?
      if existing_user.confirmed?
        UserMailer.new_account_warning(existing_user, @procedure).deliver_later
      else
        existing_user.resend_confirmation_instructions
      end
      return redirect_to after_inactive_sign_up_path_for(existing_user)
    end

    super do
      resource.update_preferred_domain(Current.host) if resource.valid?
    end
  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  # protected

  # You can put the params you want to permit in the empty array.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.for(:sign_up) << :attribute
  # end

  # You can put the params you want to permit in the empty array.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.for(:account_update) << :attribute
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  def after_inactive_sign_up_path_for(resource)
    flash.discard(:notice) # Remove devise's default message (as we have a custom page to explain it)
    signed_email = message_encryptor_service.encrypt_and_sign(resource.email, purpose: :email_confirmation, expires_in: 1.hour)
    new_user_confirmation_path(email: signed_email)
  end

  private

  def user_email_param
    # Strong Parameters silently filters non-scalar values, so a hash like
    # `user[email][]=x` would fall through to `find_by({})` and return the first user.
    email = params.require(:user).permit(:email)[:email]
    email.is_a?(String) ? email : nil
  end
end
