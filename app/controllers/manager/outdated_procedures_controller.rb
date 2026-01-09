# frozen_string_literal: true

module Manager
  class OutdatedProceduresController < Manager::ApplicationController
    def index
      @records_per_page = params[:records_per_page] || "10"
      resources = Procedure
        .where(procedure_expires_when_termine_enabled: false)
        .order(created_at: :asc)
        .page(params[:_page])
        .per(@records_per_page)
      page = Administrate::Page::Collection.new(dashboard)

      render locals: {
        resources: resources,
        page: page,
        show_search_bar: false,
      }
    end

    def bulk_update
      # rubocop:disable Style/CollectionMethods
      procedure_ids = params[:procedure][:ids].select { |_id, selected| selected == "1" }
        .keys
      # rubocop:enable Style/CollectionMethods
      successes = procedure_ids.map do |id|
        procedure = Procedure.find(id)
        success = procedure.update(procedure_expires_when_termine_enabled: true)
        if success
          administration_emails = procedure.administrateurs.map(&:email)
          administration_emails.each do |email|
            AdministrateurMailer.notify_procedure_expires_when_termine_forced(email, procedure).deliver_later
          end
        end
        success
      end

      flash[:notice] = "L’archivage automatique a été activé sur les #{successes.size} procédure(s) choisies"
      redirect_to manager_outdated_procedures_path
    end
  end
end
