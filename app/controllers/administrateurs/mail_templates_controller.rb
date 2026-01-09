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
      @preview_service = DossierPreviewService.new(procedure: @procedure, current_user:)
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
        @preview_service = DossierPreviewService.new(procedure: @procedure, current_user:)
        render :edit
      end
    end

    def preview
      mail_template = find_mail_template_by_slug(params[:id])
      @preview_service = DossierPreviewService.new(procedure: @procedure, current_user:)
      @dossier = @preview_service.dossier
      @logo_url = @procedure.logo_url
      @service = @procedure.service
      @rendered_template = sanitize(mail_template.body_for_dossier(@dossier), scrubber: Sanitizers::MailScrubber.new)
      @actions = mail_template.actions_for_dossier(@dossier)

      render(template: 'notification_mailer/send_notification', layout: 'mailers/notifications_layout')
    end

    private

    def find_mail_template_by_slug(slug)
      mail_template_map = {
        Mails::InitiatedMail::SLUG => :passer_en_construction_email_template,
        Mails::ReceivedMail::SLUG => :passer_en_instruction_email_template,
        Mails::ClosedMail::SLUG => :accepter_email_template,
        Mails::RefusedMail::SLUG => :refuser_email_template,
        Mails::WithoutContinuationMail::SLUG => :classer_sans_suite_email_template,
        Mails::ReInstructedMail::SLUG => :repasser_en_instruction_email_template
      }

      @procedure.send(mail_template_map.fetch(slug) { raise ActiveRecord::RecordNotFound })
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
