# frozen_string_literal: true

module Instructeurs
  class RdvsController < InstructeurController
    before_action :set_dossier

    def create
      # TODO: remove this once ENV are fixed in dev env
      host = helpers.app_host_legacy?(request) ? ENV.fetch("APP_HOST_LEGACY") : ENV.fetch("APP_HOST")

      first_name = @dossier.individual&.prenom || @dossier.user.france_connect_informations.first&.given_name || "Usager"
      last_name = @dossier.individual&.nom || @dossier.user.france_connect_informations.first&.family_name || "Démarche Numérique"

      @rdv_plan_result = RdvService.new(rdv_connection: current_instructeur.rdv_connection).create_rdv_plan(
        dossier: @dossier,
        first_name:,
        last_name:,
        email: @dossier.user_email_for(:notification),
        dossier_url: instructeur_dossier_url(@dossier.procedure, @dossier, host:),
        return_url: rendez_vous_instructeur_dossier_url(@dossier.procedure, @dossier, host:)
      )

      if @rdv_plan_result.success?
        return redirect_to @rdv_plan_result.value!.rdv_plan_url, allow_other_host: true
      end

      Sentry.capture_message("Rdv creation failed", extra: { rdv_plan_result: @rdv_plan_result })

      redirect_to instructeur_dossier_path(@dossier.procedure, @dossier), alert: "Erreur lors de la création du rendez-vous"
    rescue RdvService::RevokedConnectionError
      redirect_to rendez_vous_instructeur_dossier_path(@dossier.procedure, @dossier, statut: params[:statut]), alert: t('instructeurs.rdv_connections.revoked')
    end

    private

    def set_dossier
      @dossier = current_instructeur.dossiers.find(params[:dossier_id])
    end
  end
end
