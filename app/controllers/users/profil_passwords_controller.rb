# frozen_string_literal: true

module Users
  # Namespace volontairement plat. Un contrôleur à trois niveaux
  # (Users::Profil::PasswordsController) casse la résolution relative de
  # contrôleur de `current_page?` dans les partials de navigation partagés :
  # Rails ne remonte que d'un segment et cherche
  # `users/administrateurs/procedures`.
  class ProfilPasswordsController < UserController
    include ProfilContextConcern

    def edit
    end

    def update
      return render_blank_password if password_params[:password].blank?

      if current_user.update_with_password(password_params)
        bypass_sign_in(current_user)
        UserMailer.password_changed(current_user).deliver_later
        flash.notice = t('.success')
        redirect_to profil_path(context: params[:context])
      else
        render :edit, status: :unprocessable_content
      end
    end

    # Devise interdit tout le parcours « mot de passe oublié » a un utilisateur
    # connecté (require_no_authentication sur new, create, edit et update), y
    # compris le lien reçu par mail. On le déconnecte donc explicitement plutôt
    # que de lever ce garde-fou pour toute l'application.
    def forgot
      sign_out(current_user)

      flash.notice = t('.signed_out')
      # 303 : Turbo transforme le lien en soumission de formulaire, et ne suit
      # la redirection d'un POST que sur un See Other.
      redirect_to new_user_password_path, status: :see_other
    end

    private

    # Devise retire password et password_confirmation des params quand le
    # nouveau mot de passe est vide, et update({}) renvoie alors true.
    def render_blank_password
      current_user.errors.add(:password, :blank)
      render :edit, status: :unprocessable_content
    end

    def password_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
    end
  end
end
