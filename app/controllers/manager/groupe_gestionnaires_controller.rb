# frozen_string_literal: true

module Manager
  class GroupeGestionnairesController < Manager::ApplicationController
    def add_gestionnaire
      groupe_gestionnaire = GroupeGestionnaire.find(params[:id])
      emails = [params['emails']].compact
      emails = emails.map { EmailSanitizableConcern::EmailSanitizer.sanitize(_1) }

      gestionnaires_to_add, valid_emails, invalid_emails = Gestionnaire.find_all_by_identifier_with_emails(emails:)
      not_found_emails = valid_emails - gestionnaires_to_add.map(&:email)

      # Send invitations to users without account
      if not_found_emails.present?
        gestionnaires_to_add += not_found_emails.map do |email|
          user = User.create_or_promote_to_gestionnaire(email, SecureRandom.hex)
          user.invite_gestionnaire!(groupe_gestionnaire)
          user.gestionnaire
        end
      end

      # We dont't want to assign a user to an groupe_gestionnaire if they are already assigned to it
      gestionnaires_duplicate = gestionnaires_to_add & groupe_gestionnaire.gestionnaires
      gestionnaires_to_add -= groupe_gestionnaire.gestionnaires
      gestionnaires_to_add.each { groupe_gestionnaire.add_gestionnaire(_1) }

      if invalid_emails.present?
        flash[:alert] = t('activerecord.wrong_address',
          count: invalid_emails.size,
          emails: invalid_emails.join(', '))
      end
      if gestionnaires_duplicate.present?
        flash[:alert] = t('activerecord.errors.duplicate_email',
          count: invalid_emails.size,
          emails: gestionnaires_duplicate.map(&:email).join(', '))
      end

      if gestionnaires_to_add.present?
        flash[:notice] = t('groupe_gestionnaires.flash.notice.groupe_gestionnaire_gestionnaire.create')

        GroupeGestionnaireMailer
          .notify_added_gestionnaires(groupe_gestionnaire, gestionnaires_to_add, current_super_admin.email)
          .deliver_later
      end

      redirect_to manager_groupe_gestionnaire_path(groupe_gestionnaire)
    end

    def remove_gestionnaire
      groupe_gestionnaire = GroupeGestionnaire.find(params[:id])
      if groupe_gestionnaire.is_root? && groupe_gestionnaire.gestionnaires.one?
        flash[:alert] = t('groupe_gestionnaires.flash.alert.groupe_gestionnaire_gestionnaire.destroy_at_least_one')
      else
        gestionnaire = Gestionnaire.find(params[:gestionnaire][:id])

        if !groupe_gestionnaire.in?(gestionnaire.groupe_gestionnaires) || !gestionnaire.groupe_gestionnaires.destroy(groupe_gestionnaire)
          flash[:alert] = t('groupe_gestionnaires.flash.alert.groupe_gestionnaire_gestionnaire.not_in_groupe_gestionnaire', email: gestionnaire.email)
        else
          if gestionnaire.groupe_gestionnaires.empty?
            gestionnaire.destroy
          end
          flash[:notice] = t('groupe_gestionnaires.flash.notice.groupe_gestionnaire_gestionnaire.destroy', email: gestionnaire.email)
          GroupeGestionnaireMailer
            .notify_removed_gestionnaire(groupe_gestionnaire, gestionnaire.email, current_super_admin.email)
            .deliver_later
        end
      end

      redirect_to manager_groupe_gestionnaire_path(groupe_gestionnaire)
    end
  end
end
