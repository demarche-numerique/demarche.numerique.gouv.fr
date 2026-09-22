# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/avis_mailer
class AvisMailer < ApplicationMailer
  include RevokedExpertGuardConcern

  layout 'mailers/layout'

  def avis_invitation_and_confirm_email(user, token, avis) # ensure re-entrance if existing AvisMailer.avis_invitation in queue
    # visible_by_administration? is wider than the not_hidden_by_administration
    # scope — it also drops brouillon and user-hidden dossiers — so it stays a
    # Ruby filter rather than folding into the query above.
    avis = not_revoked_avis(avis).filter { it.dossier.visible_by_administration? }

    return if avis.empty?

    email = user.email
    @avis = avis
    @avis_unique = avis.first
    @multiple = avis.many?

    @confirmation_token =
      if user.active? && !user.unverified_email?
        nil
      else
        token
      end

    targeted_user_link = @avis_unique.targeted_user_links
      .find_or_create_by(target_context: 'avis',
                                                target_model_type: Avis.name,
                                                target_model_id: @avis_unique.id,
                                                user: user)

    @url = targeted_user_link_url(id: targeted_user_link.id, confirmation_token: @confirmation_token.presence, batch: @multiple)

    if !user.active?
      @call_to_action = "Inscrivez-vous pour donner votre avis"
    elsif user.unverified_email?
      @call_to_action = 'Confirmez votre adresse électronique pour donner votre avis'
    elsif @multiple
      @call_to_action = 'Toutes vos demandes d’avis pour cette démarche'
    else
      @call_to_action = 'Donnez votre avis'
    end

    if @multiple
      subject = "Donnez votre avis sur plusieurs dossiers"
      @claimant_email = @avis_unique.claimant.email
    else
      subject = "Donnez votre avis sur le dossier n° #{@avis_unique.dossier.id} (#{@avis_unique.dossier.procedure.libelle})"
      @claimant_email = @avis_unique.claimant.email
    end

    bypass_unverified_mail_protection!

    mail(to: email, subject: subject)
  end

  # i18n-tasks-use t("avis_mailer.#{action}.subject")
  def notify_new_commentaire_to_expert(dossier, avis, expert)
    return if not_revoked_avis(avis).empty?

    I18n.with_locale(dossier.user_locale) do
      @dossier = dossier
      @avis = avis
      @subject = default_i18n_subject(dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle)

      mail(to: expert.email, subject: @subject)
    end
  end

  def self.critical_email?(action_name)
    action_name == "avis_invitation_and_confirm_email"
  end
end
