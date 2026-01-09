# frozen_string_literal: true

module Gestionnaires
  class GroupeGestionnaireAdministrateursController < GestionnaireController
    before_action :retrieve_groupe_gestionnaire

    def index
    end

    def create
      emails = [params.require(:administrateur)[:email]].compact
      emails = emails.map { EmailSanitizableConcern::EmailSanitizer.sanitize(_1) }

      administrateurs_to_add, valid_emails, invalid_emails = Administrateur.find_all_by_identifier_with_emails(emails:)
      not_found_emails = valid_emails - administrateurs_to_add.map(&:email)

      # Send invitations to users without account
      if not_found_emails.present?
        administrateurs_to_add += not_found_emails.map do |email|
          user = User.create_or_promote_to_administrateur(email, SecureRandom.hex)
          user.invite_administrateur!
          user.administrateur
        end
      end
      administrateurs_already_in_groupe_gestionnaire = []
      # We dont't want to assign a user to an groupe_gestionnaire if they are already assigned to it
      administrateurs_duplicate = administrateurs_to_add & @groupe_gestionnaire.administrateurs
      administrateurs_to_add -= @groupe_gestionnaire.administrateurs
      administrateurs_to_add.each do |administrateur|
        # We don't change administrateur.groupe_gestionnaire_id is administrateur already in another groupe_gestionnaire for which current_gestionnaire is not a gestionnaire or if current_gestionnaire is not a superAdmin
        if !current_gestionnaire.is_a?(SuperAdmin) &&
            administrateur.groupe_gestionnaire_id &&
            ((administrateur.groupe_gestionnaire.ancestor_ids + [administrateur.groupe_gestionnaire_id]) & current_gestionnaire.groupe_gestionnaire_ids).empty?
          administrateurs_already_in_groupe_gestionnaire << administrateur
          next
        end
        @groupe_gestionnaire.add_administrateur(administrateur)
      end

      if administrateurs_already_in_groupe_gestionnaire.present?
        flash[:alert] = I18n.t('activerecord.errors.administrateurs_already_in_groupe_gestionnaire',
          count: administrateurs_already_in_groupe_gestionnaire.size,
          emails: administrateurs_already_in_groupe_gestionnaire)
      end

      if invalid_emails.present?
        flash[:alert] = I18n.t('activerecord.wrong_address',
          count: invalid_emails.size,
          emails: invalid_emails.join(', '))
      end
      if administrateurs_duplicate.present?
        flash[:alert] = I18n.t('activerecord.errors.duplicate_email',
          count: invalid_emails.size,
          emails: administrateurs_duplicate.map(&:email).join(', '))
      end

      if administrateurs_to_add.present?
        flash[:notice] = I18n.t('groupe_gestionnaires.flash.notice.groupe_gestionnaire_administrateur.create')

        GroupeGestionnaireMailer
          .notify_added_administrateurs(@groupe_gestionnaire, administrateurs_to_add, current_gestionnaire.email)
          .deliver_later
      end

      @administrateur = administrateurs_to_add[0]
    end

    def destroy
      @administrateur = Administrateur.find(params[:id])
      if @groupe_gestionnaire.id != @administrateur.groupe_gestionnaire_id
        flash[:alert] = I18n.t('groupe_gestionnaires.flash.alert.groupe_gestionnaire_administrateur.not_in_groupe_gestionnaire', email: @administrateur.email)
      else
        result = AdministrateurDeletionService.new(current_gestionnaire, @administrateur).call

        case result
        in Dry::Monads::Result::Success
          logger.info("L’administrateur #{@administrateur.id} est supprimé par le gestionnaire #{current_gestionnaire.id} depuis le groupe gestionnaire #{@groupe_gestionnaire.id}")
          flash[:notice] = I18n.t('groupe_gestionnaires.flash.notice.groupe_gestionnaire_administrateur.destroy', email: @administrateur.email)
          GroupeGestionnaireMailer
            .notify_removed_administrateur(@groupe_gestionnaire, @administrateur.email, current_gestionnaire.email)
            .deliver_later
        in Dry::Monads::Result::Failure(reason)
          flash[:alert] = I18n.t('groupe_gestionnaires.flash.alert.groupe_gestionnaire_administrateur.cannot_be_deleted', email: @administrateur.email)
        end
      end
    end

    def remove
      @administrateur = Administrateur.find(params[:id])
      if @groupe_gestionnaire.id != @administrateur.groupe_gestionnaire_id
        flash[:alert] = I18n.t('groupe_gestionnaires.flash.alert.groupe_gestionnaire_administrateur.not_in_groupe_gestionnaire', email: @administrateur.email)
      else
        @administrateur.update(groupe_gestionnaire_id: nil)
        flash[:notice] = I18n.t('groupe_gestionnaires.flash.notice.groupe_gestionnaire_administrateur.remove', email: @administrateur.email)
        GroupeGestionnaireMailer
          .notify_removed_administrateur(@groupe_gestionnaire, @administrateur.email, current_gestionnaire.email)
          .deliver_later
      end
    end
  end
end
