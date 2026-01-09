# frozen_string_literal: true

module Administrateurs
  class AttestationTemplateV2sController < AdministrateurController
    before_action :retrieve_procedure
    before_action :retrieve_attestation_template
    before_action :preload_revisions, only: [:edit, :update, :create]

    def show
      @preview_service = DossierPreviewService.new(procedure: @procedure, current_user:)
      attributes = @attestation_template.render_attributes_for(dossier: @preview_service.dossier)

      @body = attributes.fetch(:body)
      @signature = attributes.fetch(:signature)

      respond_to do |format|
        format.html do
          render layout: 'attestation'
        end

        format.pdf do
          html = render_to_string('/administrateurs/attestation_template_v2s/show', layout: 'attestation', formats: [:html])

          pdf = WeasyprintService.generate_pdf(html, procedure_id: @procedure.id, path: request.path, user_id: current_user.id)

          send_data(pdf, filename: 'attestation.pdf', type: 'application/pdf', disposition: 'inline')
        end
      end
    end

    def edit
      @preview_service = DossierPreviewService.new(procedure: @procedure, current_user:)

      @buttons = [
        [
          ['Gras', 'bold', 'bold'],
          ['Italic', 'italic', 'italic'],
          ['Souligner', 'underline', 'underline'],
        ],
        [
          ['Titre', 'title', :hidden], # only for "title" section, without any action possible
          ['Sous titre', 'heading2', 'h-1'],
          ['Titre de section', 'heading3', 'h-2'],
        ],
        [
          ['Liste à puces', 'bulletList', 'list-unordered'],
          ['Liste numérotée', 'orderedList', 'list-ordered'],
        ],
        [
          ['Aligner à gauche', 'left', 'align-left'],
          ['Aligner au centre', 'center', 'align-center'],
          ['Aligner à droite', 'right', 'align-right'],
        ],
        [
          ['Undo', 'undo', 'arrow-go-back-line'],
          ['Redo', 'redo', 'arrow-go-forward-line'],
        ],
      ]

      @attestation_template.validate
    end

    def update
      attestation_params = editor_params

      attestation_kind = @attestation_template.kind
      # toggle activation
      if @attestation_template.persisted? && @attestation_template.activated? != cast_bool(attestation_params[:activated])
        @procedure.attestation_templates_v2_for(attestation_kind).update_all(activated: attestation_params[:activated])
        render :update
        return
      end

      if @attestation_template.published? && should_edit_draft?
        @attestation_template = @attestation_template.dup
        @attestation_template.state = :draft
        @attestation_template.procedure = @procedure
      end

      @attestation_template.assign_attributes(attestation_params)

      if @attestation_template.invalid?
        flash.alert = "L’attestation contient des erreurs et n'a pas pu être enregistrée. Corriger les erreurs."
      else
        # - draft just published
        if @attestation_template.published? && should_edit_draft?
          published_template_v2 = @procedure.attestation_templates_v2_for(attestation_kind).published
          template_v1 = @procedure.attestation_template_v1

          @attestation_template.transaction do
            was_v2_published = published_template_v2.destroy_all
            was_v1 = template_v1&.destroy
            @attestation_template.save!
            flash.notice = (was_v1.present? || was_v2_published.any?) ? "La nouvelle version de l’attestation a été publiée." : "L’attestation a été publiée."
          end

          redirect_to edit_admin_procedure_attestation_template_v2_path(@procedure, attestation_kind: @attestation_template.kind)
        else
          # - draft updated
          # - or, attestation already published, without need for publication (draft procedure)
          @attestation_template.save!
          render :update
        end
      end
    end

    def create = update

    def reset
      @procedure.attestation_templates_v2_for(@attestation_template.kind).draft&.destroy_all

      flash.notice = "Les modifications ont été réinitialisées."
      redirect_to edit_admin_procedure_attestation_template_v2_path(@procedure, attestation_kind: @attestation_template.kind)
    end

    private

    def retrieve_attestation_template
      attestation_kind = params[:attestation_kind]

      attestation_templates_by_kind = @procedure.attestation_templates_v2_for(attestation_kind)
      @attestation_template = attestation_templates_by_kind.find(&:draft?) || attestation_templates_by_kind.find(&:published?) || build_default_attestation(attestation_kind)
    end

    def build_default_attestation(kind)
      state = should_edit_draft? ? :draft : :published
      @procedure.attestation_templates.build(version: 2, json_body: AttestationTemplate::TIPTAP_BODY_DEFAULT, activated: true, state:, kind:)
    end

    def should_edit_draft?
      if @procedure.brouillon?
        @procedure.attestation_templates.v1.published.any?
      else
        true
      end
    end

    def editor_params
      params.required(:attestation_template).permit(:activated, :official_layout, :label_logo, :label_direction, :tiptap_body, :footer, :logo, :signature, :activated, :state)
    end
  end
end
