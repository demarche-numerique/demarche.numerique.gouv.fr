# frozen_string_literal: true

module Administrateurs
  class SVASVRDisablingsController < AdministrateurController
    before_action :retrieve_procedure
    before_action :ensure_disablable

    def new
      @pending_dossiers_count, @earliest_decision_on = @procedure.sva_svr_pending_dossiers.pick(Arel.sql('COUNT(*), MIN(sva_svr_decision_on)'))
    end

    def create
      if params[:confirm] != '1' && @procedure.sva_svr_pending_dossiers.exists?
        redirect_to new_admin_procedure_sva_svr_disabling_path(@procedure) and return
      end

      @procedure.disable_sva_svr

      if @procedure.save
        flash.notice = t('.notice', rule: @procedure.sva_svr_configuration.human_decision)
        redirect_to admin_procedure_path(@procedure)
      else
        flash.alert = @procedure.errors.full_messages
        redirect_to edit_admin_procedure_sva_svr_path(@procedure)
      end
    end

    private

    def ensure_disablable
      redirect_to edit_admin_procedure_sva_svr_path(@procedure) if !@procedure.sva_svr_disablable?
    end
  end
end
