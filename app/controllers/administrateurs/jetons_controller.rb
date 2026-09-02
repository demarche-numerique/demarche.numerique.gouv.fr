# frozen_string_literal: true

module Administrateurs
  class JetonsController < AdministrateurController
    before_action :retrieve_procedure

    def index
    end

    def edit_particulier
    end

    def update_particulier
      # Un jeton collé traîne des espaces ; un champ vidé arrive en chaîne vide,
      # qui serait chiffrée puis stockée comme une valeur.
      @procedure.api_particulier_token = params[:procedure][:api_particulier_token].to_s.strip.presence
      alert = unusable_token_alert

      if alert.present?
        flash.now.alert = alert
        render :edit_particulier
      elsif @procedure.save
        flash.notice = 'Le jeton a bien été mis à jour'
        redirect_to admin_procedure_jetons_path(id: @procedure.id)
      else
        flash.now.alert = "Mise à jour impossible : le jeton n’est pas valide"
        render :edit_particulier
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
        render :edit_entreprise
      end
    end

    def destroy_entreprise
      @procedure.update!(api_entreprise_token: nil)
      flash.notice = 'Le jeton API Entreprise a bien été supprimé'
      redirect_to admin_procedure_jetons_path(@procedure)
    end

    private

    # Un jeton expiré, ou dont la charge utile n'est pas un objet, se décode :
    # rien ne le refuserait, et les appels seraient coupés dès l'enregistrement.
    def unusable_token_alert
      token = @procedure.api_particulier_token
      return if token.jwt_token.blank? || !token.unusable?

      if token.expires_at.present?
        "Mise à jour impossible : ce jeton a expiré"
      else
        "Mise à jour impossible : le jeton n’est pas valide"
      end
    end
  end
end
