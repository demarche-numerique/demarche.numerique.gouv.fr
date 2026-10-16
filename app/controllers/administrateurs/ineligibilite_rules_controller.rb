# frozen_string_literal: true

module Administrateurs
  class IneligibiliteRulesController < AdministrateurController
    before_action :retrieve_procedure

    def edit
    end

    def change
      draft_revision.assign_attributes(procedure_revision_params)

      if draft_revision.validate(:ineligibilite_rules_editor) && draft_revision.save
        flash[:notice] = "Les conditions d’inéligibilité ont été modifiées."
        redirect_to [:admin, @procedure]
      else
        flash[:alert] = draft_revision.errors.full_messages
        render :edit
      end
    end

    def add_row
      condition = Logic.add_empty_condition_to(draft_revision.ineligibilite_rules)
      draft_revision.update!(ineligibilite_rules: condition)
      @ineligibilite_rules_component = build_ineligibilite_rules_component
    end

    def delete_row
      condition = condition_form.delete_row(row_index).to_condition
      draft_revision.update!(ineligibilite_rules: condition)

      @ineligibilite_rules_component = build_ineligibilite_rules_component
    end

    def update
      condition = condition_form.to_condition
      draft_revision.update!(ineligibilite_rules: condition)

      @ineligibilite_rules_component = build_ineligibilite_rules_component
    end

    def change_targeted_champ
      condition = condition_form.change_champ(row_index).to_condition
      draft_revision.update!(ineligibilite_rules: condition)
      @ineligibilite_rules_component = build_ineligibilite_rules_component
    end

    private

    def build_ineligibilite_rules_component
      Conditions::IneligibiliteRulesComponent.new(draft_revision: draft_revision)
    end

    def draft_revision
      @procedure.draft_revision
    end

    def condition_form
      ConditionForm.new(ineligibilite_rules_params.merge(source_tdcs: draft_revision.public_flat_type_de_champs))
    end

    def ineligibilite_rules_params
      params
        .require(:procedure_revision)
        .require(:condition_form)
        .permit(:top_operator_name, rows: [:targeted_champ, :operator_name, :value])
    end

    def row_index
      params[:row_index].to_i
    end

    def procedure_revision_params
      params
        .require(:procedure_revision)
        .permit(:ineligibilite_message, :ineligibilite_enabled)
    end
  end
end
