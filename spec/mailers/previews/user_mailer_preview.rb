# frozen_string_literal: true

class UserMailerPreview < ActionMailer::Preview
  def new_account_warning
    UserMailer.new_account_warning(user)
  end

  def new_account_warning___with_procedure
    procedure = Procedure.new(libelle: 'Dotation d’Équipement des Territoires Ruraux - Exercice 2019', path: 'dotation-etr')
    UserMailer.new_account_warning(user, procedure)
  end

  def ask_for_merge
    UserMailer.ask_for_merge(user, 'dircab@territoires.gouv.fr')
  end

  def france_connect_merge_confirmation
    UserMailer.france_connect_merge_confirmation('new.exemple.fr', '123456', 15.minutes.from_now)
  end

  def send_archive
    UserMailer.send_archive(Instructeur.first, Procedure.first, Archive.first)
  end

  def invite_instructeur
    UserMailer.invite_instructeur(user, 'aedfa0d0')
  end

  def invite_tiers
    UserMailer.invite_tiers(user, 'aedfa0d0', Dossier.first)
  end

  def invite_gestionnaire
    groupe_gestionnaire = GroupeGestionnaire.new(name: 'Root admins group')
    UserMailer.invite_gestionnaire(user, 'aedfa0d0', groupe_gestionnaire)
  end

  def notify_inactive_close_to_deletion
    UserMailer.notify_inactive_close_to_deletion(user)
  end

  def notify_after_closing
    UserMailer.notify_after_closing(user, "Cette démarche est close")
  end

  def account_reactivated
    UserMailer.account_reactivated(user)
  end

  def password_changed
    UserMailer.password_changed(user)
  end

  private

  def user
    User.new(id: 10, email: 'test@exemple.fr')
  end
end
