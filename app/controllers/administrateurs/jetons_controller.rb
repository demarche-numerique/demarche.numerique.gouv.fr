# frozen_string_literal: true

module Administrateurs
  class JetonsController < AdministrateurController
    before_action :retrieve_procedure

    def index
      @api_entreprise_scopes = APIEntreprise::PrivilegesAdapter.new(@procedure.api_entreprise_token).scopes
    end

    def edit_particulier
    end

    def update_particulier
      @procedure.api_particulier_token = params[:procedure][:api_particulier_token]

      if @procedure.invalid?
        flash.now.alert = @procedure.errors.full_messages
        render :edit_particulier
      elsif scopes.empty?
        flash.now.alert = t('.no_scopes_token')
        render :edit_particulier
      else
        @procedure.update!(api_particulier_scopes: scopes, api_particulier_sources: {})

        redirect_to admin_procedure_api_particulier_sources_path(@procedure),
          notice: t('.token_ok')
      end

    rescue APIParticulier::Error::Unauthorized
      flash.now.alert = t('.not_found_token')
      render :edit_particulier
    rescue APIParticulier::Error::HttpError
      flash.now.alert = t('.network_error')
      render :edit_particulier
    end

    def destroy_particulier
      @procedure.update!(
        api_particulier_token: nil,
        api_particulier_sources: nil,
        api_particulier_scopes: nil
      )

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
        render :edit_entreprise
      end
    end

    def destroy_entreprise
      @procedure.update!(api_entreprise_token: nil)
      flash.notice = 'Le jeton API Entreprise a bien été supprimé'
      redirect_to admin_procedure_jetons_path(@procedure)
    end

    private

    def scopes
      @scopes ||= APIParticulier::API.new(params[:procedure][:api_particulier_token]).scopes
    end
  end
end
