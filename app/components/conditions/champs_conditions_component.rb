# frozen_string_literal: true

class Conditions::ChampsConditionsComponent < Conditions::ConditionsComponent
  def initialize(tdc:, upper_tdcs:, procedure:)
    @tdc, @condition, @source_tdcs = tdc, tdc.condition, upper_tdcs
    @procedure = procedure
    @champ_value_in_condition = procedure.champ_value_in_condition?
  end

  private

  def logic_conditionnel_button
    html_class = 'fr-btn fr-btn--tertiary fr-btn--sm'

    if @condition.nil?
      submit_tag(
        t('.enable_conditionnel'),
        formaction: add_condition_path,
        class: html_class
      )
    else
      submit_tag(
        t('.disable_conditionnel'),
        formmethod: 'delete',
        formnovalidate: true,
        data: { confirm: t('.disable_conditionnel_alert') },
        class: html_class
      )
    end
  end

  def add_condition_path
    add_row_admin_procedure_condition_path(@procedure.id, @tdc.stable_id)
  end

  def delete_condition_path(row_index)
    delete_row_admin_procedure_condition_path(@procedure.id, @tdc.stable_id, row_index: row_index)
  end

  def input_id_for(name, row_index)
    "#{@tdc.stable_id}-#{name}-#{row_index}"
  end

  def input_prefix
    'type_de_champ[condition_form]'
  end
end
