# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  # GET /resource/confirmation/new
  def new
    # Allow displaying the user email in the message
    decoded_email = message_encryptor_service.decrypt_and_verify(params[:email], purpose: :email_confirmation) rescue nil
    self.resource = resource_class.new(email: decoded_email)
  end

  # POST /resource/confirmation
  # def create
  #   super
  # end

  # GET /resource/confirmation?confirmation_token=abcdef
  def show
    super do
      # When email was already confirmed, default is to render :new with a specific error.
      # Because our :new is customized with the email and a form to resend a confirmation,
      # we redirect to after confirmation page instead.
      if resource.errors.of_kind?(:email, :already_confirmed)
        respond_with_navigational(resource) do
          flash.notice = t('.email_already_confirmed')
          redirect_to after_confirmation_path_for(resource_name, resource) and return
        end
      end
    end
  end

  # protected

  def user_email_param
    params.permit(user: :email).dig(:user, :email)
  end

  # The path used after resending confirmation instructions.
  # def after_resending_confirmation_instructions_path_for(resource_name)
  #   super(resource_name)
  # end

  # If the user clicks the confirmation link before the maximum delay,
  # they will be signed in directly.
  def sign_in_after_confirmation?(resource)
    # Only auto-sign-in when the confirmation actually just happened.
    # When the token is replayed after the account was already confirmed,
    # Devise adds an :already_confirmed error: in that case, the link must
    # not be turned into a reusable login token.
    return false if resource.errors.any?

    # Avoid keeping auto-sign-in links in users inboxes for too long.
    # 95% of users confirm their account within two hours.
    auto_sign_in_timeout = 2.hours
    resource.confirmation_sent_at + auto_sign_in_timeout > Time.zone.now
  end

  # The path used after confirmation.
  def after_confirmation_path_for(resource_name, resource)
    if sign_in_after_confirmation?(resource)
      resource.remember_me = true
      sign_in(resource)
    end

    if procedure_from_params
      commencer_path(path: procedure_from_params.path, prefill_token: params[:prefill_token])
    elsif signed_in?
      # Will try to use `stored_location_for` to find a path
      after_sign_in_path_for(resource_name)
    else
      super(resource_name, resource)
    end
  end

  def procedure_from_params
    params[:procedure_id] && Procedure.find_by(id: params[:procedure_id])
  end
end
