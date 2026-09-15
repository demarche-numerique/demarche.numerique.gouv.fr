# frozen_string_literal: true

module Gestionnaires
  class GroupeGestionnaireCommentairesController < GestionnaireController
    before_action :retrieve_groupe_gestionnaire
    before_action :retrieve_last_commentaire, only: [:show, :create, :destroy]
    before_action :retrieve_last_parent_groupe_gestionnaire_commentaire, only: [:index, :parent_groupe_gestionnaire, :create_parent_groupe_gestionnaire]

    def index
      @commentaires = @groupe_gestionnaire.gestionnaire_commentaires(current_gestionnaire)
        .select("sender_id, sender_type, sender_email, groupe_gestionnaire_id, MAX(id) as id, MAX(created_at) as created_at")
        .group(:sender_id, :sender_type, :sender_email, :groupe_gestionnaire_id)
        .order("MAX(id) DESC")
      @commentaires_parent_group = @commentaires.filter { |commentaire| commentaire.groupe_gestionnaire_id == @groupe_gestionnaire.parent_id }
      @commentaires_children_groups = @commentaires.filter { |commentaire| commentaire.groupe_gestionnaire_id != @groupe_gestionnaire.parent_id && commentaire.groupe_gestionnaire_id != @groupe_gestionnaire.id }
      @commentaires = @commentaires.filter { |commentaire| commentaire.groupe_gestionnaire_id == @groupe_gestionnaire.id }
    end

    def show
      @commentaire_seen_at = current_gestionnaire.commentaire_seen_at(@last_commentaire.groupe_gestionnaire, @last_commentaire.sender_id, @last_commentaire.sender_type)
      @commentaire = CommentaireGroupeGestionnaire.new
      current_gestionnaire.mark_commentaire_as_seen(@last_commentaire.groupe_gestionnaire, @last_commentaire.sender_id, @last_commentaire.sender_type)
    end

    def create
      @commentaire = @last_commentaire.groupe_gestionnaire.commentaire_groupe_gestionnaires.create(commentaire_params.merge(sender: @last_commentaire.sender, gestionnaire: current_gestionnaire))

      if @commentaire.errors.empty?
        GroupeGestionnaireMailer.notify_new_commentaire_groupe_gestionnaire(@last_commentaire.groupe_gestionnaire, @commentaire, current_gestionnaire.email, @commentaire.sender_email, @commentaire.sender_type == "Administrateur" ? admin_groupe_gestionnaire_commentaires_path : parent_groupe_gestionnaire_gestionnaire_groupe_gestionnaire_commentaires_path(@last_commentaire.groupe_gestionnaire)).deliver_later
        flash.notice = "Message envoyé"
        current_gestionnaire.mark_commentaire_as_seen(@last_commentaire.groupe_gestionnaire, @commentaire.sender_id, @commentaire.sender_type)
        redirect_to gestionnaire_groupe_gestionnaire_commentaire_path(@groupe_gestionnaire, @commentaire)
      else
        flash.alert = @commentaire.errors.full_messages
        render :show, status: :unprocessable_content
      end
    end

    def parent_groupe_gestionnaire
      if @last_commentaire
        @commentaire_seen_at = current_gestionnaire.commentaire_seen_at(@groupe_gestionnaire, current_gestionnaire.id, "Gestionnaire")
        current_gestionnaire.mark_commentaire_as_seen(@groupe_gestionnaire, current_gestionnaire.id, "Gestionnaire")
      end
      @commentaire = CommentaireGroupeGestionnaire.new
    end

    def create_parent_groupe_gestionnaire
      @commentaire = @groupe_gestionnaire.commentaire_groupe_gestionnaires.create(commentaire_params.merge(sender: current_gestionnaire))

      if @commentaire.errors.empty?
        commentaire_url = gestionnaire_groupe_gestionnaire_commentaire_url(@groupe_gestionnaire.parent, @commentaire)
        @groupe_gestionnaire.parent.gestionnaires.each do |gestionnaire|
          GroupeGestionnaireMailer.notify_new_commentaire_groupe_gestionnaire(@groupe_gestionnaire.parent, @commentaire, @commentaire.sender_email, gestionnaire.email, commentaire_url).deliver_later
        end
        current_gestionnaire.mark_commentaire_as_seen(@groupe_gestionnaire, @commentaire.sender_id, @commentaire.sender_type)
        flash.notice = "Message envoyé"
        redirect_to parent_groupe_gestionnaire_gestionnaire_groupe_gestionnaire_commentaires_path(@groupe_gestionnaire)
      else
        flash.alert = @commentaire.errors.full_messages
        render :parent_groupe_gestionnaire, status: :unprocessable_content
      end
    end

    def destroy
      if @last_commentaire.soft_deletable?(current_gestionnaire)
        @last_commentaire.soft_delete!
        @commentaire_seen_at = current_gestionnaire.commentaire_seen_at(@last_commentaire.groupe_gestionnaire, @last_commentaire.sender_id, @last_commentaire.sender_type)
        flash.notice = t('.notice')
      else
        flash.alert = t('.alert_acl')
      end
    rescue Discard::RecordNotDiscarded
      flash.alert = t('.alert_already_discarded')
    end

    private

    def retrieve_last_commentaire
      @last_commentaire = @groupe_gestionnaire.current_commentaires_groupe_and_children_commentaires_groupe.find(params[:id])
    end

    def retrieve_last_parent_groupe_gestionnaire_commentaire
      @last_commentaire = @groupe_gestionnaire.commentaire_groupe_gestionnaires&.where(sender: current_gestionnaire)&.last
    end

    def commentaire_params
      params.require(:commentaire_groupe_gestionnaire).permit(:body)
    end
  end
end
