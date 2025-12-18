# frozen_string_literal: true

class GroupeInstructeurMailer < ApplicationMailer
  layout 'mailers/layout'

  def notify_removed_instructeur(group, removed_instructeur, current_instructeur_email)
    @group = group
    @current_instructeur_email = current_instructeur_email
    @still_assigned_to_procedure = removed_instructeur.in?(group.procedure.instructeurs)
    subject = if @still_assigned_to_procedure
      "Vous avez été retiré(e) du groupe \"#{group.label}\" de la démarche \"#{group.procedure.libelle}\""
    else
      "Vous avez été désaffecté(e) de la démarche \"#{group.procedure.libelle}\""
    end

    mail(to: removed_instructeur.email, subject: subject)
  end

  def notify_added_instructeurs(group, added_instructeurs, current_instructeur_email)
    added_instructeur_emails = added_instructeurs.map(&:email)
    @group = group
    @current_instructeur_email = current_instructeur_email

    subject = if group.procedure.groupe_instructeurs.many?
      "Vous avez été ajouté(e) au groupe « #{group.label} » de la démarche « #{group.procedure.libelle} »"
    else
      "Vous avez été affecté(e) à la démarche « #{group.procedure.libelle} »"
    end

    mail(bcc: added_instructeur_emails, subject: subject)
  end

  def notify_added_instructeur_from_groupes_import(instructeur, groups, current_instructeur_email)
    @instructeur = instructeur
    @groups = groups
    @procedure = groups.first.procedure
    @current_instructeur_email = current_instructeur_email

    group_labels = groups.map(&:label).join(', ')
    subject = if groups.count == 1
      "Vous avez été affecté(e) au groupe instructeur « #{group_labels} » de la démarche « #{@procedure.libelle} »"
    else
      "Vous avez été affecté(e) à #{groups.count} groupes instructeurs de la démarche « #{@procedure.libelle} »"
    end

    mail(to: instructeur.email, subject: subject)
  end

  def self.critical_email?(action_name)
    false
  end

  def confirm_and_notify_added_instructeur_from_groupes_import(instructeur, groups, current_instructeur_email)
    @instructeur = instructeur
    @groups = groups
    @procedure = groups.first.procedure
    @current_instructeur_email = current_instructeur_email
    @reset_password_token = instructeur.user.send(:set_reset_password_token)

    group_labels = groups.map(&:label).join(', ')
    subject = if groups.count == 1
      "Vous avez été affecté(e) au groupe \"#{group_labels}\" de la démarche \"#{@procedure.libelle}\""
    else
      "Vous avez été affecté(e) à #{groups.count} groupes de la démarche \"#{@procedure.libelle}\""
    end

    bypass_unverified_mail_protection!

    mail(to: instructeur.email, subject: subject)
  end
end
