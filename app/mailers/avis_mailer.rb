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

    @claimant_email = @avis_unique.claimant.email

    bypass_unverified_mail_protection!

    use_recipient_locale(user)
    @call_to_action =
      if !user.active?
        t("avis_mailer.avis_invitation_and_confirm_email.call_to_action.sign_up")
      elsif user.unverified_email?
        t("avis_mailer.avis_invitation_and_confirm_email.call_to_action.confirm_email")
      elsif @multiple
        t("avis_mailer.avis_invitation_and_confirm_email.call_to_action.all_requests")
      else
        t("avis_mailer.avis_invitation_and_confirm_email.call_to_action.give_opinion")
      end

    subject =
      if @multiple
        t("avis_mailer.avis_invitation_and_confirm_email.subject_multiple")
      else
        t("avis_mailer.avis_invitation_and_confirm_email.subject_single", dossier_id: @avis_unique.dossier.id, libelle_demarche: @avis_unique.dossier.procedure.libelle)
      end

    mail(to: email, subject:)
  end

  # i18n-tasks-use t("avis_mailer.#{action}.subject")
  def notify_new_commentaire_to_expert(dossier, avis, expert)
    return if not_revoked_avis(avis).empty?

    use_recipient_locale(dossier.user)
    @dossier = dossier
    @avis = avis
    @subject = default_i18n_subject(dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle)

    mail(to: expert.email, subject: @subject)
  end

  # avis is the recipient's own avis on the dossier, not the one just given.
  def notify_new_avis_to_expert(avis)
    # Checked at delivery: the dossier may be deleted between enqueue and a retry.
    return if not_revoked_avis(avis).empty? || !avis.dossier.visible_by_administration?

    use_recipient_locale(avis.dossier.user)
    @dossier = avis.dossier
    @avis = avis
    @subject = default_i18n_subject(dossier_id: @dossier.id)

    mail(to: avis.expert.email, subject: @subject)
  end

  def self.critical_email?(action_name)
    action_name == "avis_invitation_and_confirm_email"
  end
end
