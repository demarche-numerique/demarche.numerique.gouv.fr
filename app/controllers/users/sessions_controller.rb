# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  include ProcedureContextConcern
  include TrustedDeviceConcern
  include ActionView::Helpers::DateHelper
  include FranceConnectConcern
  include ProConnectSessionConcern

  layout 'login', only: [:new, :create]

  before_action :restore_procedure_context, only: [:new, :create]
  skip_before_action :redirect_if_untrusted, only: [:reset_link_sent]
  # POST /resource/sign_in
  def create
    # NOTE: do not look up the user or check the password before delegating to
    # `super`. Devise's paranoid mode normalises the bcrypt timing for unknown
    # emails inside `warden.authenticate!`; a manual pre-check would only run
    # bcrypt for existing accounts and reintroduce a timing-based enumeration.
    super do |resource|
      delete_france_connect_cookies
      delete_pro_connect_session_info_cookie
      resource.update(loged_in_with_france_connect: nil)
      resource.update_preferred_domain(Current.host)
    end

    if current_account.count > 1
      flash[:notice] = t("devise.sessions.signed_in_multiple_profile", roles: current_account.keys.map { |role| t("layouts.#{role}") }.to_sentence)
    end

    # Display the trusted device renewal confirmation that was deferred when the
    # user followed the renewal link without being signed in (see #sign_in_by_link).
    if current_user && session[:trusted_device_renewal_notice].present?
      flash[:notice] = session.delete(:trusted_device_renewal_notice)
    end
  end

  def reset_link_sent
    instructeur = instructeur_from_signed_email(params[:signed_email])

    if instructeur.nil?
      redirect_to new_user_session_path, alert: t('devise.failure.unauthenticated')
      return
    end

    if send_login_token_or_bufferize(instructeur)
      flash[:notice] = "Nous venons de vous renvoyer un nouveau lien de connexion sécurisée à #{Current.application_name}"
    end

    redirect_to link_sent_path(email: signed_email_for_instructeur(instructeur))
  end

  def link_sent
    email = message_encryptor_service.decrypt_and_verify(params[:email], purpose: :reset_link) rescue nil

    if StrictEmailValidator::REGEXP.match?(email)
      @email = email
      @signed_email = params[:email]
    else
      redirect_to root_path
    end
  end

  # DELETE /resource/sign_out
  def destroy
    if user_signed_in?
      pro_connect_id_token = current_user&.instructeur&.pro_connect_id_token

      current_user.update(loged_in_with_france_connect: nil)
      current_user&.instructeur&.update(pro_connect_id_token: nil)

      sign_out :user

      delete_pro_connect_session_info_cookie

      if logged_in_with_france_connect?
        return redirect_to france_connect_logout_url(callback: root_url), allow_other_host: true
      end

      if pro_connect_id_token.present?
        return redirect_to ProConnectService.logout_url(pro_connect_id_token, host_with_port: request.host_with_port),
          allow_other_host: true
      end
    end

    respond_to_on_destroy
  end

  def no_procedure
    clear_stored_location_for(:user)
    redirect_to new_user_session_path
  end

  def sign_in_by_link
    instructeur = Instructeur.find(params[:id])
    trusted_device_token = instructeur
      .trusted_device_tokens
      .find_by(token: params[:jeton])

    if trusted_device_token.nil?
      flash[:alert] = 'Votre lien est invalide.'

      redirect_to root_path
    elsif instructeur_signed_in? && current_user != instructeur.user
      flash[:alert] = 'Votre lien est invalide.'

      redirect_to root_path
    elsif trusted_device_token.token_valid?
      trust_device(trusted_device_token.created_at, trusted_device_token)

      period = ((trusted_device_token.created_at + TRUSTED_DEVICE_PERIOD) - Time.zone.now).to_i / ActiveSupport::Duration::SECONDS_PER_DAY

      notice = "Votre connexion sécurisée a bien été renouvelée. Votre navigateur est authentifié pour #{period} jours."

      # redirect to procedure'url if stored by store_location_for(:user) in dossiers_controller
      # redirect to root_path otherwise

      if instructeur_signed_in?
        current_user.update!(email_verified_at: Time.zone.now)

        flash.notice = notice
        redirect_to after_sign_in_path_for(:user)
      else
        # The renewal is already done; the user only needs to authenticate.
        # Persist the confirmation so it is shown once signed in instead of
        # being lost on the login page.
        session[:trusted_device_renewal_notice] = notice
        flash.notice = "#{notice} Connectez-vous pour accéder à vos dossiers."
        redirect_to new_user_session_path
      end
    else
      flash[:alert] = 'Votre lien est expiré, un nouveau vient de vous être envoyé.'

      send_login_token_or_bufferize(instructeur)
      redirect_to link_sent_path(email: signed_email_for_instructeur(instructeur))
    end
  end

  # Pro connect callback
  def logout
    redirect_to root_path, notice: t('devise.sessions.signed_out')
  end

  # calling current_user in a before_action will trigger the warden authentication (devise behavior)
  # which is not what we want in a before_action of a sign_in action (current_user should be nil before explicit sign_in)
  # so we need to override current_user to avoid this
  # https://github.com/heartcombo/devise/issues/5602#issuecomment-1876164084
  def current_user
    super if warden.authenticated?(scope: :user)
  end

  private

  def signed_email_for_instructeur(instructeur)
    message_encryptor_service.encrypt_and_sign(instructeur.email, purpose: :reset_link, expires_in: 1.hour)
  end

  def instructeur_from_signed_email(signed_email)
    return if signed_email.blank?

    email = message_encryptor_service.decrypt_and_verify(signed_email, purpose: :reset_link)
    return if email.blank?

    Instructeur.by_email(email)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end
end
