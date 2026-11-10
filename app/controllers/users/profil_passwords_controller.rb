# frozen_string_literal: true

module Users
  class ProfilPasswordsController < UserController
    include ProfilContextConcern

    before_action :ensure_password_login_allowed

    helper_method :external_login_providers

    def edit
    end

    def update
      return render_blank_password if password_params[:password].blank?

      if current_user.update_with_password(password_params)
        sign_in(current_user, scope: :user, force: true, login_method: recorded_login_method)
        UserMailer.password_changed(current_user).deliver_later
        flash.notice = t('.success')
        redirect_to profil_path(context: params[:context])
      else
        render :edit, status: :unprocessable_content
      end
    end

    def forgot
      sign_out(current_user)

      flash.notice = t('.signed_out')
      redirect_to new_user_password_path, status: :see_other
    end

    private

    def ensure_password_login_allowed
      return if !current_user.administrateur&.pro_connect_required?

      flash.alert = t('users.profil_passwords.ensure_password_login_allowed.pro_connect_required')
      redirect_to profil_path(context: params[:context])
    end

    def external_login_providers
      @external_login_providers ||= [
        ('FranceConnect' if current_user.france_connect_informations.any?),
        ('ProConnect' if current_user.pro_connect_informations.any?),
      ].compact
    end

    def render_blank_password
      current_user.errors.add(:password, :blank)
      render :edit, status: :unprocessable_content
    end

    def password_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
    end
  end
end
