# frozen_string_literal: true

module InstructeurEmailNotificationConcern
  extend ActiveSupport::Concern

  # Tout user dont email_verified_at est nil — y compris un compte préexistant non encore
  # activé — reçoit le mail d'activation. Choix UX assumé : ces comptes peuvent activer
  # leur accès en un clic depuis le mail d'ajout au groupe, sans repasser par
  # « mot de passe oublié ».
  def notify_instructeurs(groupe, added_instructeurs, current_user)
    known_instructeurs, new_instructeurs = added_instructeurs.partition { |instructeur| instructeur.user.email_verified_at }

    new_instructeurs.filter(&:should_receive_email_activation?).each { GroupeInstructeurMailer.confirm_and_notify_added_instructeur(_1, groupe, current_user.email).deliver_later }

    if known_instructeurs.present?
      GroupeInstructeurMailer
        .notify_added_instructeurs(groupe, known_instructeurs, current_user.email)
        .deliver_later
    end
  end

  def notify_instructeur_added_in_many_groupes(instructeur, groupes)
    if instructeur.user.email_verified_at
      GroupeInstructeurMailer
        .notify_added_instructeur_in_many_groupes(instructeur, groupes, current_administrateur.email)
        .deliver_later
    else
      if instructeur.should_receive_email_activation?
        GroupeInstructeurMailer
          .confirm_and_notify_added_instructeur_in_many_groupes(instructeur, groupes, current_administrateur.email)
          .deliver_later
      end
    end
  end
end
