# frozen_string_literal: true

module Gestionnaires
  class GroupeGestionnaireGestionnairesController < GestionnaireController
    before_action :retrieve_groupe_gestionnaire

    def index
    end

    def create
      emails = [params.require(:gestionnaire)[:email]].compact
      emails = emails.map { EmailSanitizableConcern::EmailSanitizer.sanitize(_1) }

      gestionnaires_to_add, valid_emails, invalid_emails = Gestionnaire.find_all_by_identifier_with_emails(emails:)
      not_found_emails = valid_emails - gestionnaires_to_add.map(&:email)

      # Send invitations to users without account
      if not_found_emails.present?
        gestionnaires_to_add += not_found_emails.map do |email|
          user = User.create_or_promote_to_gestionnaire(email, SecureRandom.hex)
          user.invite_gestionnaire!(@groupe_gestionnaire)
          user.gestionnaire
        end
      end

      # We dont't want to assign a user to an groupe_gestionnaire if they are already assigned to it
      gestionnaires_duplicate = gestionnaires_to_add & @groupe_gestionnaire.gestionnaires
      gestionnaires_to_add -= @groupe_gestionnaire.gestionnaires
      gestionnaires_to_add.each { @groupe_gestionnaire.add_gestionnaire(_1) }

      if invalid_emails.present?
        flash[:alert] = I18n.t('activerecord.wrong_address',
          count: invalid_emails.size,
          emails: invalid_emails.join(', '))
      end
      if gestionnaires_duplicate.present?
        flash[:alert] = I18n.t('activerecord.errors.duplicate_email',
          count: invalid_emails.size,
          emails: gestionnaires_duplicate.map(&:email).join(', '))
      end

      if gestionnaires_to_add.present?
        flash[:notice] = I18n.t('groupe_gestionnaires.flash.notice.groupe_gestionnaire_gestionnaire.create')

        GroupeGestionnaireMailer
          .notify_added_gestionnaires(@groupe_gestionnaire, gestionnaires_to_add, current_gestionnaire.email)
          .deliver_later
      end

      @gestionnaire = gestionnaires_to_add[0]
    end

    def destroy
      if @groupe_gestionnaire.is_root? && @groupe_gestionnaire.gestionnaires.one?
        flash[:alert] = I18n.t('groupe_gestionnaires.flash.alert.groupe_gestionnaire_gestionnaire.destroy_at_least_one')
      else
        @gestionnaire = @groupe_gestionnaire.gestionnaires.find(params[:id])

        if !@gestionnaire.groupe_gestionnaires.destroy(@groupe_gestionnaire)
          flash[:alert] = I18n.t('groupe_gestionnaires.flash.alert.groupe_gestionnaire_gestionnaire.not_in_groupe_gestionnaire', email: @gestionnaire.email)
        else
          if @gestionnaire.groupe_gestionnaires.empty?
            @gestionnaire.destroy
          end
          flash[:notice] = I18n.t('groupe_gestionnaires.flash.notice.groupe_gestionnaire_gestionnaire.destroy', email: @gestionnaire.email)
          GroupeGestionnaireMailer
            .notify_removed_gestionnaire(@groupe_gestionnaire, @gestionnaire.email, current_gestionnaire.email)
            .deliver_later
        end
      end
    end
  end
end
