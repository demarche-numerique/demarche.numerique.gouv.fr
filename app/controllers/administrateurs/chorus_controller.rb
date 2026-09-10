# frozen_string_literal: true

module Administrateurs
  class ChorusController < AdministrateurController
    before_action :retrieve_procedure

    def edit
    end

    def update
      @configuration = @procedure.chorus_configuration
      @configuration.assign_attributes(configurations_params)
      if @configuration.valid?
        # Preload deliberation to avoid N+1 in before_save callback and validations
        @procedure.deliberation.attached?
        @procedure.update!(chorus: @configuration.attributes)

        if @configuration.complete?
          flash.notice = "La configuration Chorus a été mise à jour."
          redirect_to add_champ_engagement_juridique_admin_procedure_chorus_path(@procedure)
        else
          flash.notice = "La configuration Chorus a été mise à jour. Veuillez renseigner le reste des informations pour faciliter le rapprochement des données."
          redirect_to edit_admin_procedure_chorus_path(@procedure)
        end
      else
        flash.now.alert = "Des erreurs empêchent la validation du connecteur chorus. Corrigez les erreurs"
        render :edit
      end
    end

    def add_champ_engagement_juridique
    end

    private

    def search_params
      params.permit(:q)
    end

    def configurations_params
      params.require(:chorus_configuration)
        .permit(:centre_de_cout, :domaine_fonctionnel, :referentiel_de_programmation)
    end
  end
end
