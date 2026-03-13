# frozen_string_literal: true

module Administrateurs
  class ContactInformationsController < AdministrateurController
    before_action :retrieve_procedure
    before_action :retrieve_groupe_instructeur

    def new
      @contact_information = @groupe_instructeur.build_contact_information
    end

    def create
      @contact_information = @groupe_instructeur.build_contact_information(contact_information_params)
      if @contact_information.save
        redirect_to admin_procedure_groupe_instructeur_path(@procedure, @groupe_instructeur),
          notice: "Les informations de contact ont bien été ajoutées"
      else
        flash.now[:alert] = @contact_information.errors.full_messages
        render :new
      end
    end

    def edit
      @contact_information = @groupe_instructeur.contact_information
    end

    def update
      @contact_information = @groupe_instructeur.contact_information
      if @contact_information.update(contact_information_params)
        redirect_to admin_procedure_groupe_instructeur_path(@procedure, @groupe_instructeur),
          notice: "Les informations de contact ont bien été modifiées"
      else
        flash.now[:alert] = @contact_information.errors.full_messages
        render :edit
      end
    end

    def destroy
      @groupe_instructeur.contact_information.destroy
      redirect_to admin_procedure_groupe_instructeur_path(@procedure, @groupe_instructeur),
        notice: "Les informations de contact ont bien été supprimées"
    end

    private

    def retrieve_groupe_instructeur
      @groupe_instructeur = @procedure.groupe_instructeurs.find(params[:groupe_instructeur_id])
    end

    def contact_information_params
      params.require(:contact_information).permit(:nom, :email, :telephone, :horaires, :adresse)
    end
  end
end
