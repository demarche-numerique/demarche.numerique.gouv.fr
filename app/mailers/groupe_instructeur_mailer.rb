# frozen_string_literal: true

class GroupeInstructeurMailer < ApplicationMailer
  layout 'mailers/layout'

  def notify_removed_instructeur(group, removed_instructeur, current_instructeur_email)
    @group = group
    @current_instructeur_email = current_instructeur_email
    @still_assigned_to_procedure = removed_instructeur.in?(group.procedure.instructeurs)
    subject = if @still_assigned_to_procedure
      t(".subject_assigned", groupe: group.label, procedure: group.procedure.libelle)
    else
      t(".subject_unassigned", procedure: group.procedure.libelle)
    end

    mail(to: removed_instructeur.email, subject: subject)
  end

  def notify_removed_instructeur_from_many_groupes(procedure, removed_from_groupes, removed_instructeur, current_instructeur_email, still_assigned)
    @procedure = procedure
    @removed_from_groupes = removed_from_groupes
    @current_instructeur_email = current_instructeur_email
    @still_assigned_to_procedure = still_assigned

    subject = if @still_assigned_to_procedure
      t(".subject_assigned", count: removed_from_groupes.count, groupe: removed_from_groupes.first.label, procedure: procedure.libelle)
    else
      t(".subject_unassigned", procedure: procedure.libelle)
    end

    mail(to: removed_instructeur.email, subject: subject)
  end

  def notify_added_instructeurs(group, added_instructeurs, current_instructeur_email)
    added_instructeur_emails = added_instructeurs.map(&:email)
    @group = group
    @current_instructeur_email = current_instructeur_email

    subject = t(".subject", count: group.procedure.groupe_instructeurs.count, groupe: group.label, procedure: group.procedure.libelle)

    mail(bcc: added_instructeur_emails, subject: subject)
  end

  def confirm_and_notify_added_instructeur(instructeur, group, current_instructeur_email)
    @instructeur = instructeur
    @group = group
    @current_instructeur_email = current_instructeur_email
    @reset_password_token = instructeur.user.send(:set_reset_password_token)

    subject = t(".subject", count: group.procedure.groupe_instructeurs.count, groupe: group.label, procedure: group.procedure.libelle)

    bypass_unverified_mail_protection!

    mail(to: instructeur.email, subject: subject)
  end

  def notify_added_instructeur_in_many_groupes(instructeur, groups, current_instructeur_email)
    @instructeur = instructeur
    @groups = groups
    @procedure = groups.first.procedure
    @current_instructeur_email = current_instructeur_email

    subject = t(".subject", count: groups.count, groupe: groups.first.label, procedure: @procedure.libelle)

    mail(to: instructeur.email, subject: subject)
  end

  def self.critical_email?(action_name)
    ["confirm_and_notify_added_instructeur", "confirm_and_notify_added_instructeur_in_many_groupes"].include?(action_name)
  end

  def confirm_and_notify_added_instructeur_in_many_groupes(instructeur, groups, current_instructeur_email)
    @instructeur = instructeur
    @groups = groups
    @procedure = groups.first.procedure
    @current_instructeur_email = current_instructeur_email
    @reset_password_token = instructeur.user.send(:set_reset_password_token)

    subject = t(".subject", count: groups.count, groupe: groups.first.label, procedure: @procedure.libelle)

    bypass_unverified_mail_protection!

    mail(to: instructeur.email, subject: subject)
  end
end
