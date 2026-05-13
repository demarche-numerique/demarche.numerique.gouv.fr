# frozen_string_literal: true

module Users
  class DossiersPersonnalisationController < UserController
    before_action :ensure_eligible

    def edit
      @procedures_presentations = load_procedures_presentations
    end

    private

    def ensure_eligible
      return if current_user.dossiers_personnalisables?
      redirect_to dossiers_path
    end

    def load_procedures_presentations
      user_procedures = current_user.dossiers.visible_by_user
        .includes(:procedure)
        .map(&:procedure)
        .uniq

      user_procedures.sort_by { |p| -last_dossier_updated_at(p).to_i }
        .index_with { |p| presentation_for(p) }
    end

    def last_dossier_updated_at(procedure)
      current_user.dossiers.joins(:procedure).where(procedures: { id: procedure.id }).maximum(:updated_at)
    end

    def presentation_for(procedure)
      current_user.user_procedure_presentations.find_or_initialize_by(procedure_id: procedure.id)
    end
  end
end
