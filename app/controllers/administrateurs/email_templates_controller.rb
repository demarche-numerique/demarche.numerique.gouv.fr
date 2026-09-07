# frozen_string_literal: true

module Administrateurs
  class EmailTemplatesController < AdministrateurController
    include ActionView::Helpers::SanitizeHelper
    before_action :retrieve_procedure
    before_action :preload_revisions

    def index
      @email_templates = @procedure.email_templates
      @email_templates.each(&:validate)
    end

    def edit
      @email_template = find_email_template_by_slug(params[:id])
      @dossier = preview_dossier
      if !@email_template.valid?
        flash.now.alert = @email_template.errors.full_messages
      end
    end

    def show
      redirect_to edit_admin_procedure_email_template_path(@procedure.id, params[:id])
    end

    def update
      email_template = find_email_template_by_slug(params[:id])

      if email_template.update(email_template_params(email_template))
        flash.notice = "Email mis à jour"
        redirect_to edit_admin_procedure_email_template_path(email_template.procedure_id, email_template.class.const_get(:SLUG))
      else
        flash.now.alert = "L’email contient des erreurs et n’a pas pu être enregistré. Veuillez les corriger"
        @email_template = email_template
        @dossier = preview_dossier
        render :edit
      end
    end

    def switch_to_combined
      if @procedure.legacy_declarative_emails?
        # update! runs the procedure-wide validations and can raise: without the
        # transaction the depose template would be gone and the flag left behind.
        Procedure.transaction do
          @procedure.email_depose_templates.destroy_all
          @procedure.update!(combined_declarative_email: true)
        end

        flash.notice = t('.switched')
      end

      redirect_to admin_procedure_email_templates_path(@procedure)
    end

    def preview
      email_template = find_email_template_by_slug(params[:id])
      submitted = preview_params(email_template)

      if submitted.present?
        email_template.assign_attributes(submitted)
      else
        # Initial preview: mirror what the editor shows (the legacy body/subject
        # converted to tiptap), so it matches the editor before any change is saved.
        email_template.json_body = email_template.tiptap_body_doc if email_template.json_body.blank?
        email_template.json_subject = email_template.tiptap_subject_doc if email_template.json_subject.blank?
      end

      @dossier = preview_dossier
      @logo_url = @procedure.logo_url
      @service = @procedure.service
      @actions = email_template.actions_for_dossier(@dossier)

      # The subject and the body are two separate editors that each post only their
      # own field, so a request carries just one of them. Refresh only the side that
      # changed: re-rendering the other would fall back to its saved value and clobber
      # that editor's live preview.
      respond_to do |format|
        format.html do
          @rendered_template = rendered_email_body(email_template, @dossier)
          render(template: 'notification_mailer/send_notification', layout: 'mailers/layout')
        end
        format.turbo_stream do
          @updated_body = submitted.key?('tiptap_body')
          @updated_subject = submitted.key?('tiptap_subject')
          if @updated_body
            @rendered_template = rendered_email_body(email_template, @dossier)
            @email_body_html = render_to_string(template: 'notification_mailer/send_notification', formats: [:html], layout: 'mailers/layout')
          end
          @subject_preview = email_template.subject_for_dossier(@dossier) if @updated_subject
        end
      end
    end

    private

    # The preview needs a sample dossier: prefer one on the draft revision, otherwise
    # fall back to the active (published) revision so a published procedure still previews.
    def preview_dossier
      @procedure.dossier_for_preview(current_user) || @procedure.active_revision.dossier_for_preview(current_user)
    end

    def find_email_template_by_slug(slug)
      # An editor rendered before the rename posts the legacy slug, and its route
      # is served here rather than redirected (see config/routes/administrateur.rb).
      slug = Emails::LEGACY_SLUGS.fetch(slug, slug)

      @procedure.email_templates.find { |template| template.class.const_get(:SLUG) == slug } ||
        raise(ActiveRecord::RecordNotFound, "unknown email template slug: #{slug.inspect}")
    end

    def rendered_email_body(email_template, dossier)
      sanitize(email_template.body_for_dossier(dossier), scrubber: Sanitizers::MailScrubber.new)
    end

    def email_template_params(email_template)
      params.expect(submitted_param_key(email_template) => [:tiptap_body, :tiptap_subject])
    end

    def preview_params(email_template)
      params.fetch(submitted_param_key(email_template), {}).permit(:tiptap_body, :tiptap_subject)
    end

    def submitted_param_key(email_template)
      return Emails::PARAM_KEY if params.key?(Emails::PARAM_KEY)

      Emails::LEGACY_PARAM_KEYS.fetch(email_template.class.const_get(:SLUG), Emails::PARAM_KEY)
    end
  end
end
