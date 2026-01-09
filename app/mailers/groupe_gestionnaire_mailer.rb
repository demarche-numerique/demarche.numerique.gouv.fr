# frozen_string_literal: true

class GroupeGestionnaireMailer < ApplicationMailer
  layout 'mailers/layout'

  def notify_removed_gestionnaire(groupe_gestionnaire, removed_gestionnaire_email, current_super_admin_email)
    @groupe_gestionnaire = groupe_gestionnaire
    @current_super_admin_email = current_super_admin_email
    subject = "Vous avez été retiré(e) du groupe gestionnaire \"#{groupe_gestionnaire.name}\""

    mail(to: removed_gestionnaire_email, subject: subject)
  end

  def notify_added_gestionnaires(groupe_gestionnaire, added_gestionnaires, current_super_admin_email)
    added_gestionnaire_emails = added_gestionnaires.map(&:email)
    @groupe_gestionnaire = groupe_gestionnaire
    @current_super_admin_email = current_super_admin_email

    subject = "Vous avez été ajouté(e) en tant que gestionnaire du groupe gestionnaire \"#{groupe_gestionnaire.name}\""

    mail(bcc: added_gestionnaire_emails, subject: subject)
  end

  def notify_removed_administrateur(groupe_gestionnaire, removed_administrateur_email, current_super_admin_email)
    @groupe_gestionnaire = groupe_gestionnaire
    @current_super_admin_email = current_super_admin_email
    subject = "Vous avez été retiré(e) du groupe gestionnaire \"#{groupe_gestionnaire.name}\""

    mail(to: removed_administrateur_email, subject: subject)
  end

  def notify_added_administrateurs(groupe_gestionnaire, added_administrateurs, current_super_admin_email)
    added_administrateur_emails = added_administrateurs.map(&:email)
    @groupe_gestionnaire = groupe_gestionnaire
    @current_super_admin_email = current_super_admin_email

    subject = "Vous avez été ajouté(e) en tant qu’administrateur du groupe gestionnaire \"#{groupe_gestionnaire.name}\""

    mail(bcc: added_administrateur_emails, subject: subject)
  end

  def notify_new_commentaire_groupe_gestionnaire(groupe_gestionnaire, commentaire, sender_email, recipient_email, commentaire_url)
    @groupe_gestionnaire = groupe_gestionnaire
    @commentaire = commentaire
    @sender_email = sender_email
    @commentaire_url = commentaire_url
    @subject = "Vous avez un nouveau message dans le groupe gestionnaire \"#{groupe_gestionnaire.name}\""

    mail(to: recipient_email, subject: @subject)
  end

  def self.critical_email?(action_name)
    false
  end
end
