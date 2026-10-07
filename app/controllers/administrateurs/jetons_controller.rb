# frozen_string_literal: true

module Administrateurs
  class JetonsController < AdministrateurController
    before_action :retrieve_procedure

    def index
    end

    def edit_particulier
    end

    def update_particulier
      string_token = params[:procedure][:api_particulier_token]
      @procedure.api_particulier_token = string_token

      if @procedure.save
        flash.notice = 'Le jeton a bien été mis à jour'
        redirect_to admin_procedure_jetons_path(id: @procedure.id)
      else
        flash.now.alert = "Mise à jour impossible : le jeton n’est pas valide"
        render :edit_particulier, status: :unprocessable_content
      end
    end

    def destroy_particulier
      @procedure.update!(api_particulier_token: nil)
      flash.notice = 'Le jeton API Particulier a bien été supprimé'
      redirect_to admin_procedure_jetons_path(@procedure)
    end

    def edit_entreprise
    end

    def update_entreprise
      string_token = params[:procedure][:api_entreprise_token]
      jwt_token = APIEntrepriseToken.new(string_token)

      @procedure.api_entreprise_token = string_token

      if APIEntreprise::PrivilegesAdapter.new(jwt_token).valid? && @procedure.save
        flash.notice = 'Le jeton a bien été mis à jour'
        redirect_to admin_procedure_jetons_path(id: @procedure.id)
      else
        flash.now.alert = "Mise à jour impossible : le jeton n’est pas valide"
        render :edit_entreprise, status: :unprocessable_content
      end
    end

    def destroy_entreprise
      @procedure.update!(api_entreprise_token: nil)
      flash.notice = 'Le jeton API Entreprise a bien été supprimé'
      redirect_to admin_procedure_jetons_path(@procedure)
    end
  end
end
