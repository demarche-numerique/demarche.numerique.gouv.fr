# frozen_string_literal: true

module Administrateurs
  class SVASVRController < AdministrateurController
    before_action :retrieve_procedure

    def show
      redirect_to edit_admin_procedure_sva_svr_path(@procedure.id)
    end

    def edit
      @configuration = @procedure.sva_svr_configuration
    end

    def update
      @configuration = @procedure.sva_svr_configuration
      @configuration.assign_attributes(configuration_params)

      if @configuration.invalid?
        flash.now.alert = "Des erreurs empêchent la validation du SVA/SVR. Corrigez les erreurs"
        render :edit and return
      end

      @procedure.assign_attributes(sva_svr: @configuration.attributes)

      if @procedure.valid?
        @procedure.save!
        flash.notice = "La configuration SVA/SVR a été mise à jour et prend immédiatement effet pour les nouveaux dossiers."
        redirect_to admin_procedure_path(@procedure)
      else
        flash.alert = @procedure.errors.full_messages
        redirect_to edit_admin_procedure_sva_svr_path(@procedure)
      end
    end

    private

    def configuration_params
      params.require(:sva_svr_configuration).permit(:decision, :period, :unit, :resume)
    end
  end
end
