# frozen_string_literal: true

module Administrateurs
  class AttestationTemplatesController < AdministrateurController
    before_action :retrieve_procedure
    before_action :preload_revisions

    def show
      redirect_to edit_admin_procedure_attestation_template_path(@procedure)
    end

    def edit
      @attestation_template = build_attestation_template
      @attestation_template.validate
    end

    def update
      @attestation_template = @procedure.attestation_template_v1

      if @attestation_template.update(activated_attestation_params)
        flash.notice = "Le modèle de l’attestation a bien été modifié"

        redirect_to edit_admin_procedure_attestation_template_path(@procedure)
      else
        flash.now.alert = "Le modèle de l’attestation contient des erreurs et n’a pas pu être enregistré. Veuiller les corriger"

        render :edit
      end
    end

    def create
      @attestation_template = build_attestation_template(activated_attestation_params)

      if @attestation_template.save
        flash.notice = "Le modèle de l’attestation a bien été enregistré"

        redirect_to edit_admin_procedure_attestation_template_path(@procedure)
      else
        flash.now.alert = @attestation_template.errors.full_messages

        render :edit
      end
    end

    def preview
      @attestation = build_attestation_template.render_attributes_for({})

      render 'administrateurs/attestation_templates/show', formats: [:pdf]
    end

    private

    def build_attestation_template(attributes = {})
      attestation_template = @procedure.attestation_template_v1 || @procedure.build_attestation_template_v1
      attestation_template.attributes = attributes
      attestation_template
    end

    def activated_attestation_params
      # cache result to avoid multiple uninterlaced computations
      if @activated_attestation_params.nil?
        @activated_attestation_params = params.require(:attestation_template)
          .permit(:title, :body, :footer, :activated, :logo, :signature, :kind)
      end

      @activated_attestation_params
    end
  end
end
