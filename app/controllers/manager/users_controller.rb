# frozen_string_literal: true

module Manager
  class UsersController < Manager::ApplicationController
    def update
      user = User.find(params[:id])
      targeted_user = User.find_by(email: targeted_email)

      if targeted_user.nil?
        user.skip_reconfirmation!
        user.update(email: targeted_email)

        if (user.valid?)
          flash[:notice] = "L’adresse électronique a été modifiée en « #{targeted_email} » sans notification ni validation par email."
        else
          flash[:error] = user.errors.full_messages.to_sentence
        end

        redirect_to edit_manager_user_path(user)
      else
        targeted_user.merge(user)

        flash[:notice] = "Le compte « #{targeted_email} » a absorbé le compte « #{user.email} »."
        redirect_to edit_manager_user_path(targeted_user)
      end
    end

    def unblock_mails
      user = User.find(params[:id])
      user.update!(email_verified_at: Time.current)
      flash[:notice] = "Les emails ont été débloqués."
      redirect_to manager_user_path(user)
    end

    def resend_confirmation_instructions
      user = User.find(params[:id])
      user.resend_confirmation_instructions
      flash[:notice] = "L’email d’activation de votre compte a été renvoyé."
      redirect_to manager_user_path(user)
    end

    def resend_reset_password_instructions
      user = User.find(params[:id])
      user.send_reset_password_instructions
      flash[:notice] = "L’email de réinitialisation du mot de passe a été renvoyé."
      redirect_to manager_user_path(user)
    end

    # Only the administrateur dashboard currently exposes FeaturesField;
    # revisit (e.g. accept the group as a param) if usager/instructeur dashboards start using it.
    FEATURES_GROUP = "administrateur"

    def enable_feature
      user = User.find(params[:id])
      allowed_keys = FeaturesField.available_features(FEATURES_GROUP).map(&:key).to_set

      params.fetch(:features, {}).each do |key, enable|
        next unless allowed_keys.include?(key)

        if enable
          Flipper.enable_actor(key.to_sym, user)
        else
          Flipper.disable_actor(key.to_sym, user)
        end
      end

      head :ok
    end

    def delete
      user = User.find(params[:id])
      if !user.can_be_deleted?
        fail "Impossible de supprimer cet utilisateur. Il a des dossiers en instruction ou il est administrateur."
      end
      user.delete_and_keep_track_dossiers_also_delete_user(current_super_admin, reason: :user_removed)

      logger.info("L’utilisateur #{user.id} est supprimé par #{current_super_admin.id}")
      flash[:notice] = "L’utilisateur #{user.id} est supprimé"

      redirect_to manager_users_path
    end

    def emails
      @user = User.find(params[:id])

      email_services = [
        Brevo::API.new,
        Scaleway::API.new,
      ].filter(&:properly_configured?)

      @sent_mails = Concurrent::Array.new
      email_services.map do |api|
        Thread.new do
          mails = api.sent_mails(@user.email)
          @sent_mails.concat(mails)
        end
      end.each(&:join)

      @sent_mails.sort_by!(&:delivered_at).reverse!
    end

    def unblock_email
      @user = User.find(params[:user_id])
      if Brevo::API.new.unblock_user(@user.email)
        flash.notice = "L’adresse électronique a été débloquée auprès de Brevo"
      else
        flash.alert = "Impossible de débloquer cette adresse électronique auprès de Brevo"
      end
      redirect_to emails_manager_user_path(@user)
    end

    def reactivate
      user = User.find(params[:id])

      if user.blocked_at.nil?
        flash[:notice] = "Ce compte n'est pas bloqué."
      else
        user.update!(blocked_at: nil, blocked_reason: nil)
        UserMailer.account_reactivated(user).deliver_later
        logger.info("L'utilisateur #{user.id} a été réactivé par #{current_super_admin.id}")
        flash[:notice] = "Le compte de l'utilisateur #{user.email} a été réactivé."
      end

      redirect_to manager_user_path(user)
    end

    private

    def targeted_email
      params.require(:user).permit(:email)[:email]
    end

    def paginate_resources(_resources)
      super.without_count
    end
  end
end
