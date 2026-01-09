# frozen_string_literal: true

module Administrateurs
  class ServicesController < AdministrateurController
    skip_before_action :alert_for_missing_siret_service, only: :edit
    skip_before_action :alert_for_missing_service, only: :edit
    def index
      @procedure = procedure
      @services = ([procedure.service].compact + services.ordered).uniq
    end

    def new
      @procedure = procedure
      @service = Service.new

      siret = current_administrateur.user.last_pro_connect_information&.siret
      if siret
        @service.siret = siret
        @prefilled = handle_siret_prefill
      end
    end

    def create
      @service = Service.new(service_params)
      @service.administrateur = current_administrateur

      if @service.save
        @service.enqueue_api_entreprise

        redirect_to admin_services_path(procedure_id: params[:procedure_id]),
          notice: "#{@service.nom} créé"
      else
        @procedure = procedure
        flash[:alert] = @service.errors.full_messages
        render :new
      end
    end

    def edit
      @service = service
      @procedure = procedure
    end

    def update
      @service = service

      if @service.update(service_params)
        if @service.siret_previously_changed?
          @service.enqueue_api_entreprise
        end

        redirect_to admin_services_path(procedure_id: params[:procedure_id]),
          notice: "#{@service.nom} modifié"
      else
        @procedure = procedure
        flash[:alert] = @service.errors.full_messages
        render :edit
      end
    end

    def prefill
      @procedure = procedure
      @service = Service.new(siret: params[:siret])

      prefilled = handle_siret_prefill

      render turbo_stream: turbo_stream.replace(
        "service_form",
        partial: "administrateurs/services/form",
        locals: { service: @service, prefilled:, procedure: @procedure }
      )
        end

    def add_to_procedure
      procedure = current_administrateur.procedures.find(procedure_params[:id])
      service = services.find(procedure_params[:service_id])

      procedure.update(service: service)

      redirect_to admin_procedure_path(procedure.id),
        notice: "service affecté : #{procedure.service.nom}"
    end

    def destroy
      service_to_destroy = service

      if service_to_destroy.procedures.present?
        if service_to_destroy.procedures.count == 1
          message = "la démarche #{service_to_destroy.procedures.first.libelle} utilise encore le service #{service_to_destroy.nom}. Veuillez l’affecter à un autre service avant de pouvoir le supprimer"
        else
          message = "les démarches #{service_to_destroy.procedures.map(&:libelle).join(', ')} utilisent encore le service #{service.nom}. Veuillez les affecter à un autre service avant de pouvoir le supprimer"
        end
        flash[:alert] = message
        redirect_to admin_services_path(procedure_id: params[:procedure_id])
      else
        service_to_destroy.procedures.with_discarded.discarded.update(service: nil)
        service_to_destroy.destroy
        redirect_to admin_services_path(procedure_id: params[:procedure_id]),
          notice: "#{service_to_destroy.nom} est supprimé"
      end
    end

    private

    def service_params
      params.require(:service).permit(:nom, :organisme, :type_organisme, :email, :telephone, :horaires, :adresse, :siret, :faq_link, :contact_link, :other_contact_info)
    end

    def service
      services.find(params[:id])
    end

    def services
      service_ids = current_administrateur.service_ids
      service_ids << maybe_procedure&.service_id
      Service.where(id: service_ids.compact.uniq)
    end

    def procedure_params
      params.require(:procedure).permit(:id, :service_id)
    end

    def maybe_procedure
      current_administrateur.procedures.find_by(id: params[:procedure_id])
    end

    def procedure
      current_administrateur.procedures.find(params[:procedure_id])
    end

    def handle_siret_prefill
      @service.validate

      if !@service.errors.include?(:siret)
        prefilled = case @service.prefill_from_siret
        in [Dry::Monads::Result::Success, Dry::Monads::Result::Success]
          :success
        in [Dry::Monads::Result::Failure, Dry::Monads::Result::Success] | [Dry::Monads::Result::Success, Dry::Monads::Result::Failure]
          :partial
        else
          :failure
        end
      end

      # On prefill from SIRET, we only want to display errors for the SIRET input
      # so we have to remove other errors (ie. required attributes not yet filled)
      siret_errors = @service.errors.where(:siret)
      @service.errors.clear
      siret_errors.each { @service.errors.import(_1) }

      prefilled
    end
  end
end
