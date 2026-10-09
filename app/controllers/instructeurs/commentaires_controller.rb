# frozen_string_literal: true

module Instructeurs
  class CommentairesController < ApplicationController
    include InstructeurConcern
    before_action :authenticate_instructeur_or_expert!
    before_action :retrieve_procedure_presentation, if: :instructeur_of_dossier?
    after_action :mark_messagerie_as_read, if: :instructeur_of_dossier?
    helper_method :instructeur_of_dossier?

    def destroy
      connected_user = current_instructeur || current_expert

      if !commentaire.soft_deletable?(connected_user, cancel_correction: false)
        flash.alert = t('.alert_not_deletable')
      else
        commentaire.soft_delete!
        set_notifications if instructeur_of_dossier?
        flash.notice = t('.notice')
      end
    rescue Discard::RecordNotDiscarded
      # i18n-tasks-use t('instructeurs.commentaires.destroy.alert_already_discarded')
      flash.alert = t('.alert_already_discarded')
    end

    def cancel_correction
      if commentaire.sent_by?(current_instructeur)
        if commentaire.dossier_correction&.pending?
          commentaire.cancel_correction!
          set_notifications if instructeur_of_dossier?
          flash.notice = t('.notice')
        else
          flash.alert = t('.alert_no_pending_correction')
        end
      else
        flash.alert = t('.alert_acl')
      end
    end

    private

    def mark_messagerie_as_read
      if commentaire.sent_by?(current_instructeur)
        current_instructeur.mark_tab_as_seen(commentaire.dossier, :messagerie)
      end
    end

    def dossier
      @dossier ||= instructeur_dossier ||
        current_expert&.avis&.not_revoked&.find_by(dossier_id: params[:dossier_id])&.dossier ||
        raise(ActiveRecord::RecordNotFound)
    end

    # The user may be an expert on this dossier and an instructeur elsewhere:
    # instructeur-only behaviour requires access to the dossier as instructeur.
    def instructeur_dossier
      return @instructeur_dossier if defined?(@instructeur_dossier)

      @instructeur_dossier = current_instructeur&.dossiers&.visible_by_administration&.find_by(id: params[:dossier_id])
    end

    def instructeur_of_dossier?
      instructeur_dossier.present?
    end

    def commentaire
      @commentaire ||= dossier
        .commentaires
        .find(params[:id])
    end
  end
end
