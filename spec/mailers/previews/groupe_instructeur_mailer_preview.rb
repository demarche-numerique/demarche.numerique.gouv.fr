# frozen_string_literal: true

class GroupeInstructeurMailerPreview < ActionMailer::Preview
  def notify_removed_instructeur
    procedure = Procedure.new(id: 1, libelle: 'une superbe procedure')
    groupe = GroupeInstructeur.new(id: 1, label: 'Val-De-Marne', procedure:)
    current_instructeur_email = 'admin@dgfip.com'
    instructeur = Instructeur.last
    GroupeInstructeurMailer.notify_removed_instructeur(groupe, instructeur, current_instructeur_email)
  end

  def notify_added_instructeurs
    procedure = Procedure.new(id: 1, libelle: 'une superbe procedure')
    groupe = GroupeInstructeur.new(id: 1, label: 'Val-De-Marne', procedure:)
    current_instructeur_email = 'admin@dgfip.com'
    instructeurs = Instructeur.limit(2)
    GroupeInstructeurMailer.notify_added_instructeurs(groupe, instructeurs, current_instructeur_email)
  end

  def notify_added_instructeur_from_groupes_import
    procedure = Procedure.new(id: 1, libelle: 'une superbe procedure')
    groups = [GroupeInstructeur.new(id: 1, label: 'Val-De-Marne', procedure:), GroupeInstructeur.new(id: 2, label: 'Seine-Saint-Denis', procedure:)]
    current_instructeur_email = 'admin@dgfip.com'
    instructeur = Instructeur.last
    GroupeInstructeurMailer.notify_added_instructeur_from_groupes_import(instructeur, groups, current_instructeur_email)
  end

  def confirm_and_notify_added_instructeur_from_groupes_import
    procedure = Procedure.new(id: 1, libelle: 'une superbe procedure')
    groups = [GroupeInstructeur.new(id: 1, label: 'Val-De-Marne', procedure:), GroupeInstructeur.new(id: 2, label: 'Seine-Saint-Denis', procedure:)]
    current_instructeur_email = 'admin@dgfip.com'
    instructeur = Instructeur.last
    @reset_password_token = instructeur.user.send(:set_reset_password_token)
    GroupeInstructeurMailer.confirm_and_notify_added_instructeur_from_groupes_import(instructeur, groups, current_instructeur_email)
  end
end
