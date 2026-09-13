# frozen_string_literal: true

module Gestionnaires
  class GestionnaireController < ApplicationController
    before_action :authenticate_gestionnaire!

    def nav_bar_profile
      :gestionnaire
    end

    def retrieve_groupe_gestionnaire
      id = params[:groupe_gestionnaire_id] || params[:id]
      @groupe_gestionnaire = GroupeGestionnaire.find(id)
      if ((@groupe_gestionnaire.ancestor_ids + [@groupe_gestionnaire.id]) & current_gestionnaire.groupe_gestionnaire_ids).empty?
        raise(ActiveRecord::RecordNotFound)
      end

      Sentry.set_tags(groupe_gestionnaire: @groupe_gestionnaire.id)
    rescue ActiveRecord::RecordNotFound
      flash.alert = 'Groupe inexistant'
      redirect_to gestionnaire_groupe_gestionnaires_path, status: 404
    end
  end
end
