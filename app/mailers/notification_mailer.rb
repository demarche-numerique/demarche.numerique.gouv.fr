# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/notification_mailer

# A Notification is attached as a Comment to the relevant discussion,
# then sent by email to the user.
#
# The subject and body of a Notification can be customized by each demarche.
#
class NotificationMailer < ApplicationMailer
  JDMA_STATES = [Dossier.states.fetch(:en_construction)] + Dossier::TERMINE

  before_action :set_dossier, except: [:send_notification_for_tiers, :send_accuse_lecture_notification]
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

    @subject = default_i18n_subject(first_name: @dossier.mandataire_first_name, last_name: @dossier.mandataire_last_name)
    @email = @dossier.individual.email
    @logo_url = procedure_logo_url(@dossier.procedure)

    mail(subject: @subject, to: @email, template_name: 'send_notification_for_tiers')
  end

  def send_accuse_lecture_notification(dossier)
    @dossier = dossier
    @dossier.with_revision
    @subject = default_i18n_subject(dossier_id: @dossier.id, libelle: @dossier.procedure.libelle.truncate_words(50))
    @email = @dossier.user_email_for(:notification)

    @logo_url = procedure_logo_url(@dossier.procedure)

    mail(subject: @subject, to: @email, template_name: 'send_accuse_lecture_notification')
  end

  def self.send_depose_notification(dossier)
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

  def set_jdma
    return if @dossier.skip_user_notification_email?
    return if !JDMA_STATES.include?(params[:state])

    # On utilise le widget de l'administrateur s'il en a collé un.
    @jdma_link = MonAvisEmbed.new(@dossier.procedure.monavis_embed).link_href("email")
    return if @jdma_link.present?

    # Sinon, Services Publics + porte sur le traitement du dossier. C'est l'état
    # visé par le modèle qui tranche, et non celui passé au mailer : l'email
    # déclaratif combiné annonce l'acceptation depuis « en construction ».
    if @email_template.class::DOSSIER_STATE.in?(Dossier::TERMINE)
      @jdma_link = ENV['SERVICES_PUBLICS_PLUS_URL'].presence
    end
  end

  def set_dossier
    @dossier = params[:dossier]
    @dossier.with_revision

    if @dossier.skip_user_notification_email?
      mail.perform_deliveries = false
    else
      I18n.with_locale(@dossier.user_locale) do
        @email_template = @dossier.email_template_for(params[:state])
        email_template_presenter = EmailTemplatePresenterService.new(@dossier, params[:state])

        @email = @dossier.user_email_for(:notification)
        @rendered_template = email_template_presenter.safe_body
        @subject = email_template_presenter.safe_subject
        @actions = @email_template.actions_for_dossier(@dossier)
        @attachment = @email_template.attachment_for_dossier(@dossier)
      end
    end
  end
end
