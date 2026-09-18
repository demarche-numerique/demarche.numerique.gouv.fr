# frozen_string_literal: true

module Instructeurs
  class InstructeurController < ApplicationController
    before_action :authenticate_instructeur!
    before_action :ensure_pro_connect_if_required!

    def nav_bar_profile
      :instructeur
    end

    def ensure_not_super_admin!
      if instructeur_as_manager?
        redirect_back_or_to(root_url, alert: "Interdit aux super admins", status: 403)
      end
    end

    private

    def ensure_pro_connect_if_required!
      return if logged_in_with_pro_connect?

      procedure_ids = pro_connect_procedure_ids.compact_blank
      return if procedure_ids.empty?
      return if !current_instructeur.procedures.with_discarded.not_pro_connect_restriction_none.exists?(id: procedure_ids)

      redirect_to_pro_connect_required_for_procedure
    end

    # Ids of the procedures the action works on, read from the request before
    # the controller loads anything, so that their ProConnect restriction
    # applies whatever the way the action loads them. The procedure of the
    # dossier counts on its own: a dossier is not always looked up within the
    # procedure_id of the url. Controllers working on another record override
    # this method.
    def pro_connect_procedure_ids
      procedure_ids = [params[:procedure_id]]
      procedure_ids += procedure_ids_of(Dossier.where(id: params[:dossier_id])) if params[:dossier_id].present?
      procedure_ids
    end

    def procedure_ids_of(dossiers)
      dossiers.joins(:revision).pluck(ProcedureRevision.arel_table[:procedure_id])
    end

    def instructeur_as_manager?
      procedure_id = params[:procedure_id]

      current_instructeur.assign_to
        .where(instructeur: current_instructeur,
               groupe_instructeur: current_instructeur.groupe_instructeurs.where(procedure_id: procedure_id),
               manager: true)
        .count
        .positive?
    end
  end
end
