# frozen_string_literal: true

module Instructeurs
  class ProcedurePresentationController < InstructeurController
    before_action :set_procedure_presentation, only: [:update, :refresh_filters, :update_filter, :persist_filters, :toggle_filters_expanded, :customize_filters, :clear_all_filters]

    # updates the value of a filter
    def update_filter
      if !@procedure_presentation.update_filter_for_statut(params[:statut], params[:filter_key], filtered_column_from_params)
        flash.alert = filters_error_messages
      end

      render turbo_stream: turbo_stream.refresh
    end

    # updates the filters in customization without saving them
    def refresh_filters
      customize_filters_component = Instructeurs::CustomizeFiltersComponent.new(
        procedure_presentation: @procedure_presentation,
        statut: params[:statut],
        filters_columns: filters_columns_from_params,
        apply_to_all_tabs: apply_to_all_tabs_from_params
      )

      render turbo_stream: turbo_stream.replace(customize_filters_component.id, customize_filters_component)
    end

    def toggle_filters_expanded
      @procedure_presentation.update!(filters_expanded: params[:filters_expanded])

      editable_filters_component = Instructeurs::EditableFiltersComponent.new(procedure_presentation: @procedure_presentation, instructeur_procedure: @instructeur_procedure, statut: params[:statut])

      render turbo_stream: turbo_stream.replace(editable_filters_component.id, editable_filters_component)
    end

    def update
      if @procedure_presentation.update(procedure_presentation_params)
        toggle_admin_default = params.dig(:procedure_presentation, :admin_default_procedure_presentation_active_virtual)
        set_admin_pp_default if toggle_admin_default.present? && current_instructeur_administrates_procedure?
      else
        flash.alert = filters_error_messages
      end

      redirect_back_or_to([:instructeur, procedure])
    end

    def persist_filters
      if apply_to_all_tabs_from_params
        @procedure_presentation.replace_all_filters!(filters_columns_from_params)
      else
        @procedure_presentation.replace_filters!(params[:statut], filters_columns_from_params)
      end

      redirect_to instructeur_procedure_path(procedure, statut: params[:statut])
    end

    def customize_filters
      @procedure = @procedure_presentation.procedure
      @statut = params[:statut]
      @apply_to_all_tabs = apply_to_all_tabs_from_params
      @filters_columns = @procedure_presentation.filters_for(@statut).map(&:column)
      render layout: "empty_layout"
    end

    def clear_all_filters
      @procedure_presentation.clear_filters_values_for_statut!(params[:statut])

      render turbo_stream: turbo_stream.refresh
    end

    private

    def apply_to_all_tabs_from_params
      params[:apply_to_all_tabs] == '1'
    end

    def filters_columns_from_params
      # Resolve columns within this presentation's own procedure, so a forged id
      # pointing at another procedure is ignored rather than read.
      Array(params[:filters_columns]).uniq.filter_map { own_column_from_id(it) }
    end

    def own_column_from_id(raw_id)
      procedure.find_column(h_id: JSON.parse(raw_id, symbolize_names: true))
    rescue ActiveRecord::RecordNotFound, JSON::ParserError, TypeError
      nil
    end

    # complicated way to display inner error messages
    def filters_error_messages
      @procedure_presentation.errors
        .flat_map { _1.detail[:value].flat_map { |c| c.errors.full_messages } }
    end

    def filtered_column_from_params
      params_hash = filter_params.to_h.deep_stringify_keys

      if params_hash.key?('filter')
        params_hash['filter'] = ValueNormalizer.normalize(params_hash['filter'])
        params_hash['filter']['value'] = params_hash['filter']['value']&.reject(&:empty?)&.uniq
      end

      FilteredColumnType.new.cast(params_hash)
    end

    def current_instructeur_administrates_procedure?
      current_instructeur.user.administrateur&.owns?(procedure)
    end

    def set_admin_pp_default
      admin_active_default = ActiveModel::Type::Boolean.new.cast(params[:procedure_presentation][:admin_default_procedure_presentation_active_virtual])

      @procedure_presentation.procedure.update(
        admin_default_procedure_presentation_active: admin_active_default,
        admin_default_procedure_presentation_id: admin_active_default ? @procedure_presentation.id : nil
      )
    end

    def procedure = @procedure_presentation.procedure

    def procedure_presentation_params
      h = params.permit(displayed_columns: [], sorted_column: [:order, :id], filters: [:id, :filter]).to_h

      if params[:statut].present?
        filter_name = @procedure_presentation.filters_name_for(params[:statut])
        h[filter_name] = h.delete("filters") # move filters to the right key, ex: tous_filters
      end

      if h[:displayed_columns].present?
        # React ComboBox/MultiComboBox return [''] when no value is selected
        # We need to remove them
        h[:displayed_columns] = h[:displayed_columns].reject(&:empty?)

        # when instructeur update displayed_columns, `customized` becomes true
        # we consider he knows how to use the personnalization
        h[:customized] = true
      end

      h
    end

    def filter_params
      if params[:filter].present? && params[:filter][:filter].is_a?(String) # old format
        params.require(:filter).permit(:id, :filter)
      else
        params.require(:filter).permit(:id, filter: [:operator, value: []])
      end
    end

    def pro_connect_procedure_ids
      ProcedurePresentation.where(id: params[:id]).joins(assign_to: :groupe_instructeur).pluck(GroupeInstructeur.arel_table[:procedure_id])
    end

    def set_procedure_presentation
      @procedure_presentation = ProcedurePresentation
        .includes(:assign_to)
        .find_by!(id: params[:id], assign_to: { instructeur: current_instructeur })
    end
  end
end
