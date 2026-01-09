# frozen_string_literal: true

module Manager
  class ConfirmationUrlsController < Manager::ApplicationController
    before_action :ensure_administrateur_exists
    before_action :ensure_not_already_added

    def new
      @url = new_manager_procedure_administrateur_confirmation_url(
        procedure.id,
        q: encrypt({ email: params[:email], inviter_id: current_super_admin.id })
      )
    end

    private

    def ensure_administrateur_exists
      redirect("Cet administrateur n’existe pas. Veuillez réessayer.") unless administrateur
    end

    def ensure_not_already_added
      redirect("Cet administrateur a déjà été ajouté à cette démarche.") if already_added?
    end

    def redirect(alert)
      flash[:alert] = alert
      redirect_to manager_procedure_path(procedure)
    end

    def already_added?
      AdministrateursProcedure.exists?(procedure: procedure, administrateur: administrateur)
    end

    def administrateur
      @administrateur ||= Administrateur.by_email(params[:email])
    end

    def procedure
      @procedure ||= Procedure.with_discarded.find(params[:procedure_id])
    end

    def encrypt(parameters)
      message_encryptor_service.encrypt_and_sign(parameters, purpose: :confirm_adding_administrateur)
    end
  end
end
