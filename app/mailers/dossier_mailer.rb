# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/dossier_mailer
class DossierMailer < ApplicationMailer
  class AbortDeliveryError < StandardError; end

  helper ServiceHelper
  helper ProcedureHelper

  layout 'mailers/layout'
  default from: NO_REPLY_EMAIL

  before_action :abort_perform_deliveries, only: [:notify_transfer]
  after_action :prevent_perform_deliveries, only: [:notify_new_draft, :notify_new_answer, :notify_pending_correction, :notify_transfer]

  # when we don't want to render the view
  rescue_from AbortDeliveryError, with: -> {}

  def notify_new_draft
    @dossier = params[:dossier]
    raise AbortDeliveryError if !@dossier.brouillon? || @dossier.hidden_by_user_at.present?

    I18n.with_locale(@dossier.user_locale) do
      @service = @dossier.procedure.service
      @logo_url = procedure_logo_url(@dossier.procedure)
      @subject = default_i18n_subject(libelle_demarche: @dossier.procedure.libelle)

      mail(to: @dossier.user_email_for(:notification), subject: @subject)
    end
  end

  def notify_new_answer
    commentaire = params[:commentaire]
    dossier = commentaire.dossier

    I18n.with_locale(dossier.user_locale) do
      @dossier = dossier
      @service = dossier.procedure.service
      @logo_url = procedure_logo_url(@dossier.procedure)
      @body = commentaire.body
      @subject = default_i18n_subject(dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle)

      mail(to: dossier.user_email_for(:notification), subject: @subject)
    end
  end

  def notify_new_commentaire_to_instructeur(dossier, instructeur_email)
    I18n.with_locale(dossier.user_locale) do
      @dossier = dossier
      @subject = default_i18n_subject(dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle)

      mail(to: instructeur_email, subject: @subject)
    end
  end

  def notify_pending_correction
    commentaire = params[:commentaire]
    dossier = commentaire.dossier

    I18n.with_locale(dossier.user_locale) do
      @dossier = dossier
      @service = dossier.procedure.service
      @logo_url = procedure_logo_url(@dossier.procedure)
      @correction = commentaire.dossier_correction

      @subject = default_i18n_subject(dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle)

      mail(to: dossier.user_email_for(:notification), subject: @subject)
    end
  end

  def notify_new_avis_to_instructeur(avis, instructeur_email)
    I18n.with_locale(avis.dossier.user_locale) do
      @avis = avis
      @subject = default_i18n_subject(dossier_id: avis.dossier.id, libelle_demarche: avis.procedure.libelle)

      mail(to: instructeur_email, subject: @subject)
    end
  end

  def notify_new_dossier_depose_to_instructeur(dossier, instructeur_email)
    I18n.with_locale(dossier.user_locale) do
      @dossier = dossier
      @subject = default_i18n_subject(dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle)

      mail(to: instructeur_email, subject: @subject)
    end
  end

  def notify_brouillon_near_deletion(dossiers, to_email)
    I18n.with_locale(dossiers.first.user_locale) do
      @subject = default_i18n_subject(count: dossiers.size)
      @dossiers = dossiers
      @expiration_date = Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.from_now

      mail(to: to_email, subject: @subject)
    end
  end

  def notify_brouillon_deletion(dossier_hashes, to_email)
    @subject = default_i18n_subject(count: dossier_hashes.size)
    @dossier_hashes = dossier_hashes

    mail(to: to_email, subject: @subject)
  end

  def notify_en_construction_deletion_to_administration(dossier, to_email)
    @subject = default_i18n_subject(dossier_id: dossier.id)
    @dossier = dossier

    mail(to: to_email, subject: @subject)
  end

  def notify_automatic_deletion_to_user(hidden_dossiers, to_email)
    I18n.with_locale(hidden_dossiers.first.user_locale) do
      @state = hidden_dossiers.first.state
      @subject = default_i18n_subject(count: hidden_dossiers.size)
      @hidden_dossiers = hidden_dossiers
      @deletion_date = Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks.from_now

      mail(to: to_email, subject: @subject)
    end
  end

  def notify_automatic_deletion_to_administration(hidden_dossiers, to_email)
    @subject = default_i18n_subject(count: hidden_dossiers.size)
    @hidden_dossiers = hidden_dossiers
    @deletion_date = Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks.from_now

    mail(to: to_email, subject: @subject)
  end

  def notify_near_deletion_to_user(dossiers, to_email)
    I18n.with_locale(dossiers.first.user_locale) do
      @state = dossiers.first.state
      @subject = default_i18n_subject(count: dossiers.size, state: @state)
      @dossiers = dossiers
      @expiration_date = Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.from_now

      mail(to: to_email, subject: @subject)
    end
  end

  def notify_near_deletion_to_administration(dossiers, to_email)
    @state = dossiers.first.state
    @subject = default_i18n_subject(count: dossiers.size, state: @state)
    @dossiers = dossiers
    @expiration_date = Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks.from_now

    mail(to: to_email, subject: @subject)
  end

  def notify_groupe_instructeur_changed(instructeur, dossier)
    @subject = default_i18n_subject(dossier_id: dossier.id)
    @dossier = dossier

    mail(to: instructeur.email, subject: @subject)
  end

  def notify_brouillon_not_submitted(dossier)
    I18n.with_locale(dossier.user_locale) do
      @subject = default_i18n_subject(dossier_id: dossier.id)
      @dossier = dossier

      mail(to: dossier.user_email_for(:notification), subject: @subject)
    end
  end

  def notify_transfer
    @transfer = params[:dossier_transfer]

    @user = User.find_by(email: @transfer.email)

    bypass_unverified_mail_protection!
    I18n.with_locale(@transfer.user_locale) do
      @subject = default_i18n_subject()

      mail(to: @transfer.email, subject: @subject)
    end
  end

  def notify_owner_for_changes(dossier, invite)
    I18n.with_locale(dossier.user_locale) do
      @dossier = dossier
      @invite = invite
      @subject = default_i18n_subject(dossier_id: dossier.id, email_invite: invite.email)

      mail(to: dossier.user.email, subject: @subject)
    end
  end

  def self.critical_email?(action_name)
    false
  end

  protected

  def prevent_perform_deliveries
    commentaire = params[:commentaire]
    dossier = commentaire&.dossier || params[:dossier]

    if commentaire&.discarded? || dossier&.skip_user_notification_email?
      mail.perform_deliveries = false
    end
  end

  def abort_perform_deliveries
    dossier_transfer = params[:dossier_transfer]

    if dossier_transfer.dossiers.empty?
      raise AbortDeliveryError.new
    end
  end

  # This is an override of `default_i18n_subject` method
  # https://api.rubyonrails.org/v5.0.0/classes/ActionMailer/Base.html#method-i-default_i18n_subject
  #
  # i18n-tasks-use t("dossier_mailer.#{action}.subject")
  def default_i18n_subject(interpolations = {})
    if interpolations[:state]
      mailer_scope = self.class.mailer_name.tr('/', '.')
      state = interpolations[:state].in?(Dossier::TERMINE) ? 'termine' : interpolations[:state]
      I18n.t("subject_#{state}", **interpolations.merge(scope: [mailer_scope, action_name]))
    else
      super
    end
  end
end
