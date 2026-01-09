# frozen_string_literal: true

class Users::ActivateController < ApplicationController
  include TrustedDeviceConcern
  before_action :authenticate_user!, only: [:resend_verification_email]
  def new
    @user = User.with_reset_password_token(params[:token])

    if @user
      # the user activates its account from an email
      trust_device(Time.zone.now)
    else
      flash.alert = "Le lien de validation du compte instructeur a expiré, #{helpers.contact_link('contactez-nous', tags: 'lien expiré')} pour obtenir un nouveau lien."
      redirect_to root_path
    end
  end

  def create
    user = User.reset_password_by_token({
      password: user_params[:password],
      reset_password_token: user_params[:reset_password_token],
    })

    if user.valid?
      sign_in(user, scope: :user)

      flash.notice = "Mot de passe enregistré"
      redirect_to instructeur_procedures_path
    else
      flash.alert = user.errors.full_messages
      redirect_to users_activate_path(token: user_params[:reset_password_token])
    end
  end

  def confirm_email
    user = User.find_by(confirmation_token: params[:token])
    if user && user.email_verified_at
      flash[:notice] = "Votre adresse électronique est déjà vérifié"
    elsif user && user.confirmation_sent_at >= 2.days.ago
      user.update!(email_verified_at: Time.zone.now)
      flash[:notice] = 'Votre adresse électronique a bien été vérifié'
    else
      if user.present?
        flash[:alert] = "Ce lien n’est plus valable, un nouveau lien a été envoyé à l’adresse #{user.email}"
        user.resend_confirmation_email!
      else
        flash[:alert] = "Un problème est survenu, vous pouvez nous contacter sur #{Current.contact_email}"
      end
    end
    redirect_to root_path(user)
  end

  def resend_verification_email
    user = current_user
    if user && !user.email_verified_at?
      token = SecureRandom.hex(10)
      user.update!(confirmation_token: token, confirmation_sent_at: Time.zone.now)
      user.resend_confirmation_email!
      flash[:notice] = "Un nouvel email de vérification a été envoyé à l’adresse #{user.email}."
    else
      flash[:alert] = "Votre adresse électronique est déjà vérifié ou vous n'êtes pas connecté."
    end
    redirect_to root_path(user)
  end

  private

  def user_params
    params.require(:user).permit(:reset_password_token, :password)
  end
end
