# frozen_string_literal: true

module Administrateurs
  class ConditionsController < AdministrateurController
    include Logic

    before_action :retrieve_procedure, :retrieve_coordinate_and_uppers

    def update
      condition = condition_form.to_condition
      @tdc.update!(condition: condition)

      @procedure.reload
      @condition_component = build_condition_component
    end

    def add_row
      condition = Logic.add_empty_condition_to(@tdc.condition)
      @tdc.update!(condition: condition)

      @procedure.reload
      @condition_component = build_condition_component
    end

    def delete_row
      condition = condition_form.delete_row(row_index).to_condition
      @tdc.update!(condition: condition)

      @procedure.reload
      @condition_component = build_condition_component
    end

    def destroy
      @tdc.update!(condition: nil)

      @procedure.reload
      @condition_component = build_condition_component
    end

    def change_targeted_champ
      condition = condition_form.change_champ(row_index).to_condition
      @tdc.update!(condition: condition)

      @procedure.reload
      @condition_component = build_condition_component
    end

    private

    def build_condition_component
      Conditions::ChampsConditionsComponent.new(
        tdc: @tdc,
        upper_tdcs: @upper_tdcs,
        procedure: @procedure
      )
    end

    def condition_form
      ConditionForm.new(condition_params.merge({ source_tdcs: @upper_tdcs }))
    end

    def retrieve_coordinate_and_uppers
      ProcedureRevisionPreloader.load_one(draft_revision)
      @tdc = draft_revision.find_and_ensure_exclusive_use(params[:stable_id])
      @coordinate = draft_revision.coordinate_for(@tdc)
      @upper_tdcs = @coordinate.upper_coordinates.map(&:type_de_champ)
    end

    def draft_revision
      @procedure.draft_revision
    end

    def condition_params
      params
        .require(:type_de_champ)
        .require(:condition_form)
        .permit(:top_operator_name, rows: [:targeted_champ, :operator_name, :value])
    end

    def row_index
      params[:row_index].to_i
    end
  end
end
