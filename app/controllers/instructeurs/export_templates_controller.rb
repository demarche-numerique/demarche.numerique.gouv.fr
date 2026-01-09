# frozen_string_literal: true

module Instructeurs
  class ExportTemplatesController < InstructeurController
    before_action :set_procedure_and_groupe_instructeurs
    before_action :set_export_template, only: [:edit, :update, :destroy]
    before_action :ensure_legitimate_groupe_instructeur, only: [:create, :update]
    before_action :set_types_de_champ, only: [:new, :edit]
    before_action :set_preview_service, only: [:new, :create, :edit, :update, :preview]

    def new
      @export_template = export_template
    end

    def create
      @export_template = ExportTemplate.new(export_template_params)

      if @export_template.save
        redirect_to [:export_templates, :instructeur, @procedure], notice: "Le modèle d’export #{@export_template.name} a bien été créé"
      else
        flash[:alert] = @export_template.errors.full_messages
        render :new
      end
    end

    def edit
    end

    def update
      if @export_template.update(export_template_params)
        redirect_to [:export_templates, :instructeur, @procedure], notice: "Le modèle d’export #{@export_template.name} a bien été modifié"
      else
        flash[:alert] = @export_template.errors.full_messages
        render :edit
      end
    end

    def destroy
      if @export_template.destroy
        redirect_to [:export_templates, :instructeur, @procedure], notice: "Le modèle d’export #{@export_template.name} a bien été supprimé"
      else
        redirect_to [:export_templates, :instructeur, @procedure], alert: "Le modèle d’export #{@export_template.name} n’a pu être supprimé"
      end
    end

    def preview
      export_template = ExportTemplate.new(export_template_params)

      render turbo_stream: turbo_stream.replace('preview', partial: 'preview', locals: { procedure: @procedure, export_template:, preview_service: @preview_service })
    end

    private

    def export_template = @export_template ||= ExportTemplate.default(groupe_instructeur: @groupe_instructeurs.first, kind:)

    def kind = params[:kind] == 'zip' ? 'zip' : 'xlsx'

    def set_types_de_champ
      if export_template.tabular?
        @types_de_champ_public = @procedure.all_revisions_types_de_champ(parent: nil, with_header_section: true).public_only
        @types_de_champ_private = @procedure.all_revisions_types_de_champ(parent: nil, with_header_section: true).private_only
      end
    end

    def export_template_params
      params
        .require(:export_template)
        .permit(
          :name,
          :kind,
          :shared,
          :groupe_instructeur_id,
          :commentaires_attachments,
          :avis_attachments,
          :justificatif_motivation,
          dossier_folder: [:enabled, :template],
          export_pdf: [:enabled, :template],
          attestation: [:enabled, :template],
          pjs: [:stable_id, :enabled, :template],
          exported_columns: []
        )
    end

    def set_procedure_and_groupe_instructeurs
      @procedure = current_instructeur.procedures.find(params[:procedure_id])
      @groupe_instructeurs = current_instructeur.groupe_instructeurs.where(procedure: @procedure)

      Sentry.configure_scope { |scope| scope.set_tags(procedure: @procedure.id) }
    end

    def set_export_template
      @export_template = current_instructeur.export_templates.find(params[:id])
    end

    def ensure_legitimate_groupe_instructeur
      return if export_template_params[:groupe_instructeur_id].in?(@groupe_instructeurs.map { _1.id.to_s })

      redirect_to [:export_templates, :instructeur, @procedure], alert: 'Vous n’avez pas le droit de créer un modèle d’export pour ce groupe'
    end

    def set_preview_service
      @preview_service = DossierPreviewService.new(procedure: @procedure, current_user:)
    end
  end
end
