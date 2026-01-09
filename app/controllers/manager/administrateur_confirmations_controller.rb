# frozen_string_literal: true

module Manager
  class AdministrateurConfirmationsController < Manager::ApplicationController
    before_action :set_procedure
    before_action :decrypt_params
    before_action :ensure_not_inviter, unless: -> { Rails.env.development? }
    before_action :ensure_not_invited, unless: -> { Rails.env.development? }

    def new
      @inviter = SuperAdmin.find(@inviter_id)
    end

    def create
      administrateur = Administrateur.by_email(@invited_email)
      AdministrateursProcedure.create!(procedure: @procedure, administrateur: administrateur)
      flash[:notice] = "L’administrateur \"#{administrateur.email}\" a été ajouté à la démarche."
      redirect_to manager_procedure_path(@procedure)
    end

    private

    def ensure_not_inviter
      redirect_unallowed if @inviter_id.to_i == current_super_admin.id
    end

    def ensure_not_invited
      redirect_unallowed if @invited_email == current_super_admin.email
    end

    def redirect_unallowed
      flash[:alert] = "Veuillez partager ce lien avec un autre super administrateur pour qu’il confirme votre action"
      redirect_to manager_procedure_path(@procedure)
    end

    def decrypt_params
      @inviter_id = decrypted_params[:inviter_id]
      @invited_email = decrypted_params[:email]
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      flash[:error] = "Le lien que vous avez utilisé est invalide. Veuillez contacter la personne qui vous l’a envoyé."
      redirect_to manager_procedure_path(@procedure)
    end

    def decrypted_params
      @decrypted_params ||= message_encryptor_service
        .decrypt_and_verify(params[:q], purpose: :confirm_adding_administrateur)
        .symbolize_keys
    end

    def set_procedure
      @procedure = Procedure.with_discarded.find(params[:procedure_id])
    end
  end
end
