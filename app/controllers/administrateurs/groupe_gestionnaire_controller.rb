# frozen_string_literal: true

module Administrateurs
  class GroupeGestionnaireController < AdministrateurController
    before_action :retrieve_groupe_gestionnaire, only: [:show, :administrateurs, :gestionnaires, :commentaires, :create_commentaire]

    def show
      @unread_commentaires = current_administrateur.unread_commentaires?
    end

    def administrateurs
    end

    def gestionnaires
    end

    def commentaires
      @commentaire_seen_at = current_administrateur.commentaire_seen_at
      @commentaire = CommentaireGroupeGestionnaire.new
      current_administrateur.mark_commentaire_as_seen
    end

    def create_commentaire
      @commentaire = @groupe_gestionnaire.commentaire_groupe_gestionnaires.create(commentaire_params.merge(sender: current_administrateur))

      if @commentaire.errors.empty?
        commentaire_url = gestionnaire_groupe_gestionnaire_commentaire_url(@groupe_gestionnaire, @commentaire)
        @groupe_gestionnaire.gestionnaires.includes(:groupe_gestionnaires, :commentaire_groupe_gestionnaires).find_each do |gestionnaire|
          GroupeGestionnaireMailer.notify_new_commentaire_groupe_gestionnaire(@groupe_gestionnaire, @commentaire, @commentaire.sender_email, gestionnaire.email, commentaire_url).deliver_later
        end
        current_administrateur.mark_commentaire_as_seen
        flash.notice = "Message envoyé"
        redirect_to admin_groupe_gestionnaire_commentaires_path
      else
        flash.alert = @commentaire.errors.full_messages
        render :commentaires
      end
    end

    private

    def retrieve_groupe_gestionnaire
      id = current_administrateur.groupe_gestionnaire_id
      @groupe_gestionnaire = GroupeGestionnaire.find(id)

      Sentry.configure_scope do |scope|
        scope.set_tags(groupe_gestionnaire: @groupe_gestionnaire.id)
      end
    rescue ActiveRecord::RecordNotFound
      flash.alert = 'Groupe inexistant'
      redirect_to admin_procedures_path, status: 404
    end

    def commentaire_params
      params.require(:commentaire_groupe_gestionnaire).permit(:body)
    end
  end
end
