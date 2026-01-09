# frozen_string_literal: true

module Gestionnaires
  class GroupeGestionnairesController < GestionnaireController
    before_action :retrieve_groupe_gestionnaire, only: [:show, :edit, :update, :destroy, :tree_structure]

    def index
      @groupe_gestionnaires = groupe_gestionnaires
    end

    def show
      @unread_commentaires = current_gestionnaire.unread_commentaires?(@groupe_gestionnaire)
    end

    def edit
    end

    def update
      if @groupe_gestionnaire.update(groupe_gestionnaire_params)
        flash.notice = "Le groupe a bien été modifié"

        redirect_to gestionnaire_groupe_gestionnaire_path(@groupe_gestionnaire)
      else
        flash.now.alert = "Le groupe contient des erreurs et n’a pas pu être enregistré. Veuiller les corriger"

        render :edit
      end
    end

    def destroy
      if !@groupe_gestionnaire.can_be_deleted?(current_gestionnaire)
        flash[:alert] = "Impossible de supprimer ce groupe.."
      else
        @groupe_gestionnaire.destroy

        flash[:notice] = "Le groupe #{@groupe_gestionnaire.id} est supprimé"
      end
      redirect_to gestionnaire_groupe_gestionnaires_path
    end

    def tree_structure
      @tree_structure = @groupe_gestionnaire.subtree.arrange
    end

    private

    def groupe_gestionnaires
      groupe_gestionnaire_ids = current_gestionnaire.groupe_gestionnaire_ids
      GroupeGestionnaire.where(id: groupe_gestionnaire_ids.compact.uniq)
    end

    def groupe_gestionnaire_params
      params.require(:groupe_gestionnaire).permit(:name)
    end
  end
end
