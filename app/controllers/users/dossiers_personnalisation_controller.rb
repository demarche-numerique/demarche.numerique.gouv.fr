# frozen_string_literal: true

module Users
  class DossiersPersonnalisationController < UserController
    before_action :ensure_eligible

    def edit
      @procedures_presentations = load_procedures_presentations
    end

    def update
      permitted_presentations.each do |procedure_id, attrs|
        procedure = user_procedure_from_param(procedure_id)
        next if procedure.blank?

        persist_presentation(procedure, Array(attrs[:displayed_column_ids]))
      end

      redirect_to dossiers_path, notice: t('users.dossiers_personnalisation.flash.success')
    end

    private

    def ensure_eligible
      return if current_user.dossiers_personnalisables?
      redirect_to dossiers_path
    end

    def permitted_presentations
      params.fetch(:presentations, {}).permit!.to_h
    end

    def user_procedure_from_param(procedure_id)
      Procedure
        .joins(:dossiers)
        .where(dossiers: { user_id: current_user.id })
        .where(id: procedure_id)
        .first
    end

    def persist_presentation(procedure, stable_ids)
      columns = valid_columns_for(procedure, stable_ids)
      presentation = current_user.user_procedure_presentations.find_or_initialize_by(procedure_id: procedure.id)

      if columns.empty?
        presentation.destroy if presentation.persisted?
      else
        presentation.update!(displayed_columns: columns)
      end
    end

    def valid_columns_for(procedure, stable_ids)
      authorized_types_de_champ = procedure.types_de_champ_personnalisables.where(stable_id: stable_ids).index_by { |tdc| tdc.stable_id.to_s }
      stable_ids.filter_map do |sid|
        type_de_champ = authorized_types_de_champ[sid.to_s]
        type_de_champ&.columns(procedure:)&.first
      end
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
