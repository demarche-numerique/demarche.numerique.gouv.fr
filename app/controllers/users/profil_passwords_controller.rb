# frozen_string_literal: true

module Users
  class ProfilPasswordsController < UserController
    include ProfilContextConcern

    before_action :ensure_password_login_allowed

    helper_method :external_logins

    def edit
    end

    def update
      return render_password_error(:blank) if password_params[:password].blank?
      return render_password_error(:same_as_current) if same_as_current_password?

      if current_user.update_with_password(password_params)
        sign_in(current_user, scope: :user, force: true, login_method: Current.user_session.login_method)
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

    def external_logins
      @external_logins ||= [
        (:france_connect if current_user.france_connect_informations.any?),
        (:pro_connect if current_user.pro_connect_informations.any?),
      ].compact
    end

    def same_as_current_password?
      password_params[:password] == password_params[:current_password] &&
        current_user.valid_password?(password_params[:current_password])
    end

    def render_password_error(kind)
      current_user.errors.add(:password, kind)
      render :edit, status: :unprocessable_content
    end

    def password_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
    end
  end
end
