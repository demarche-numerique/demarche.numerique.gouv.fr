# frozen_string_literal: true

module Administrateurs
  class MailTemplatesController < AdministrateurController
    include ActionView::Helpers::SanitizeHelper
    before_action :retrieve_procedure
    before_action :preload_revisions

    def index
      @mail_templates = @procedure.mail_templates
      @mail_templates.each(&:validate)
    end

    def edit
      @mail_template = find_mail_template_by_slug(params[:id])
      if !@mail_template.valid?
        flash.now.alert = @mail_template.errors.full_messages
      end
    end

    def show
      redirect_to edit_admin_procedure_mail_template_path(@procedure.id, params[:id])
    end

    def update
      mail_template = find_mail_template_by_slug(params[:id])

      if mail_template.update(update_params)
        flash.notice = "Email mis à jour"
        redirect_to edit_admin_procedure_mail_template_path(mail_template.procedure_id, params[:id])
      else
        flash.now.alert = "L’email contient des erreurs et n’a pas pu être enregistré. Veuiller les corriger"
        mail_template.rich_body = mail_template.body

        @mail_template = mail_template
        render :edit
      end
    end

    def preview
      mail_template = find_mail_template_by_slug(params[:id])
      dossier = @procedure.active_revision.dossier_for_preview(current_user)

      @dossier = dossier
      @logo_url = @procedure.logo_url
      @service = @procedure.service
      @rendered_template = sanitize(mail_template.body_for_dossier(dossier), scrubber: Sanitizers::MailScrubber.new)
      @actions = mail_template.actions_for_dossier(dossier)

      render(template: 'notification_mailer/send_notification', layout: 'mailers/layout')
    end

    private

    def find_mail_template_by_slug(slug)
      @procedure.mail_templates.find { |template| template.class.const_get(:SLUG) == slug }
    end

    def update_params
      mail_template_id = params[:id]
      {
        procedure_id: params[:procedure_id],
        subject: params["mails_#{mail_template_id}"] ? params["mails_#{mail_template_id}"][:subject] : params["mails_#{mail_template_id}_mail"][:subject],
        body: params["mails_#{mail_template_id}"] ? params["mails_#{mail_template_id}"][:rich_body] : params["mails_#{mail_template_id}_mail"][:rich_body],
      }
    end
  end
end
