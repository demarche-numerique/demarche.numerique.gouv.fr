# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/notification_mailer

# A Notification is attached as a Comment to the relevant discussion,
# then sent by email to the user.
#
# The subject and body of a Notification can be customized by each demarche.
#
class NotificationMailer < ApplicationMailer
  before_action :set_dossier, except: [:send_notification_for_tiers, :send_accuse_lecture_notification]
  before_action :set_services_publics_plus, only: :send_notification
  before_action :set_jdma, only: :send_notification

  helper ServiceHelper

  default from: NO_REPLY_EMAIL

  def send_notification
    @service = @dossier.procedure.service
    @logo_url = procedure_logo_url(@dossier.procedure)
    attachments[@attachment[:filename]] = @attachment[:content] if @attachment.present?
    I18n.with_locale(@dossier.user_locale) do
      mail(subject: @subject, to: @email, template_name: 'send_notification')
    end
  end

  def send_notification_for_tiers(dossier, repasser_en_instruction: false)
    @dossier = dossier
    @dossier.with_revision
    @repasser_en_instruction = repasser_en_instruction

    if @dossier.individual.no_notification?
      mail.perform_deliveries = false
      return
    end

    @subject = "Votre dossier rempli par le mandataire #{@dossier.mandataire_first_name} #{@dossier.mandataire_last_name} a été mis à jour"
    @email = @dossier.individual.email
    @logo_url = procedure_logo_url(@dossier.procedure)

    mail(subject: @subject, to: @email, template_name: 'send_notification_for_tiers')
  end

  def send_accuse_lecture_notification(dossier)
    @dossier = dossier
    @dossier.with_revision
    @subject = "La décision a été rendue pour votre dossier n°#{@dossier.id} (#{@dossier.procedure.libelle.truncate_words(50)})"
    @email = @dossier.user_email_for(:notification)

    @logo_url = procedure_logo_url(@dossier.procedure)

    mail(subject: @subject, to: @email, template_name: 'send_accuse_lecture_notification')
  end

  def self.send_en_construction_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:en_construction)).send_notification
  end

  def self.send_en_instruction_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:en_instruction)).send_notification
  end

  def self.send_accepte_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:accepte)).send_notification
  end

  def self.send_refuse_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:refuse)).send_notification
  end

  def self.send_sans_suite_notification(dossier)
    with(dossier: dossier, state: Dossier.states.fetch(:sans_suite)).send_notification
  end

  def self.send_repasser_en_instruction_notification(dossier)
    with(dossier: dossier, state: DossierOperationLog.operations.fetch(:repasser_en_instruction)).send_notification
  end

  def self.critical_email?(action_name)
    false
  end

  private

  def set_services_publics_plus
    return unless Dossier::TERMINE.include?(params[:state])

    @services_publics_plus_url = ENV['SERVICES_PUBLICS_PLUS_URL'].presence
  end

  def set_jdma
    if params[:state] == Dossier.states.fetch(:en_construction) && @dossier.procedure.monavis_embed
      @jdma_html = @dossier.procedure.monavis_embed_html_source("email")
    end
  end

  def set_dossier
    @dossier = params[:dossier]
    @dossier.with_revision

    if @dossier.skip_user_notification_email?
      mail.perform_deliveries = false
    else
      I18n.with_locale(@dossier.user_locale) do
        email_template = @dossier.email_template_for(params[:state])
        email_template_presenter = MailTemplatePresenterService.new(@dossier, params[:state])

        @email = @dossier.user_email_for(:notification)
        @rendered_template = email_template_presenter.safe_body
        @subject = email_template_presenter.safe_subject
        @actions = email_template.actions_for_dossier(@dossier)
        @attachment = email_template.attachment_for_dossier(@dossier)
      end
    end
  end
end
