# frozen_string_literal: true

class Conditions::ConditionsComponent < ApplicationComponent
  include Logic

  private

  def rows
    condition_per_row.map { |c| Logic.split_condition(c) }
  end

  def condition_per_row
    if [And, Or].include?(@condition.class)
      @condition.operands
    else
      [@condition].compact
    end
  end

  def far_left_tag(row_number)
    if row_number == 0
      t('.display_if')
    elsif row_number == 1
      select_tag(
        "#{input_prefix}[top_operator_name]",
        options_for_select(options_for_far_left_tag, @condition.class.name),
        class: 'fr-select'
      )
    end
  end

  def options_for_far_left_tag
    [And, Or]
      .map(&:name)
      .map { |name| [t(name, scope: 'logic.operators'), name] }
  end

  def left_operand_tag(targeted_champ, row_index)
    # current_target can be invalid if
    # - its type has changed : number -> carto
    # - it has been removed
    # - it has been put lower in the form
    current_target_valid = targets_for_select.map(&:second).include?(targeted_champ.to_json)

    selected_target = current_target_valid ? targeted_champ.to_json : empty.to_json

    select_tag(
      input_name_for('targeted_champ'),
      options_for_select(targets_for_select, selected_target),
      onchange: "this.form.action = this.form.action + '/change_targeted_champ?row_index=#{row_index}'",
      id: input_id_for('targeted_champ', row_index),
      class: { 'fr-select': true, alert: !current_target_valid }
    )
  end

  def targets_for_select
    empty_target_for_select + available_targets_for_select
  end

  def empty_target_for_select
    [[t('.select'), empty.to_json]]
  end

  def available_targets_for_select
    if column_mode?
      conditionable_targets_by_tdc
        .map { |column| [column.label + " (col)", column_value(column).to_json] }
    else
      @source_tdcs
        .filter(&:conditionable?)
        .map { |tdc| [tdc.libelle, champ_value(tdc.stable_id).to_json] }
    end
  end

  def column_mode?
    feature_enabled?(:column_conditions) && !@champ_value_in_condition
  end

  def conditionable_targets_by_tdc
    @conditionable_targets_by_tdc ||= @source_tdcs.to_h do |tdc|
      tdc.columns(procedure: @procedure)
        .filter { _1.type != :text }
        .filter { _1.type != :date }
    end
  end

  def operator_tag(operator_name, targeted_champ, row_index)
    operators_for_select = compatibles_operators_for_select(targeted_champ)

    current_operator_invalid = !operators_for_select.map(&:second).include?(operator_name)

    if current_operator_invalid
      operators_for_select = [[t('.select'), EmptyOperator.name]] + operators_for_select
    end

    select_tag(
      input_name_for('operator_name'),
      options_for_select(operators_for_select, selected: operator_name),
      id: input_id_for('operator_name', row_index),
      class: { 'fr-select': true, alert: current_operator_invalid }
    )
  end

  def compatibles_operators_for_select(left)
    case left.type(@source_tdcs)
    when ChampValue::CHAMP_VALUE_TYPE.fetch(:boolean)
      [
        [t('is', scope: 'logic'), Eq.name],
        [t('is_not', scope: 'logic'), NotEq.name],
      ]
    when ChampValue::CHAMP_VALUE_TYPE.fetch(:empty)
      [
        [t('is', scope: 'logic'), EmptyOperator.name],
      ]
    when ChampValue::CHAMP_VALUE_TYPE.fetch(:enum)
      [
        [t('is', scope: 'logic'), Eq.name],
        [t('is_not', scope: 'logic'), NotEq.name],
      ]
    when ChampValue::CHAMP_VALUE_TYPE.fetch(:commune_enum), ChampValue::CHAMP_VALUE_TYPE.fetch(:epci_enum), ChampValue::CHAMP_VALUE_TYPE.fetch(:address)
      [
        [t(InDepartementOperator.name, scope: 'logic.operators'), InDepartementOperator.name],
        [t(NotInDepartementOperator.name, scope: 'logic.operators'), NotInDepartementOperator.name],
        [t(InRegionOperator.name, scope: 'logic.operators'), InRegionOperator.name],
        [t(NotInRegionOperator.name, scope: 'logic.operators'), NotInRegionOperator.name],
      ]
    when ChampValue::CHAMP_VALUE_TYPE.fetch(:departement_enum)
      [
        [t('is', scope: 'logic'), Eq.name],
        [t('is_not', scope: 'logic'), NotEq.name],
        [t(InRegionOperator.name, scope: 'logic.operators'), InRegionOperator.name],
        [t(NotInRegionOperator.name, scope: 'logic.operators'), NotInRegionOperator.name],
      ]
    when ChampValue::CHAMP_VALUE_TYPE.fetch(:enums)
      [
        [t(IncludeOperator.name, scope: 'logic.operators'), IncludeOperator.name],
        [t(ExcludeOperator.name, scope: 'logic.operators'), ExcludeOperator.name],
      ]
    when ChampValue::CHAMP_VALUE_TYPE.fetch(:number)
      [Eq, LessThan, GreaterThan, LessThanEq, GreaterThanEq]
        .map(&:name)
        .map { |name| [t(name, scope: 'logic.operators'), name] }
    else
      []
    end
  end

  def right_operand_tag(left, right, row_index, operator_name)
    right_invalid = !current_right_valid?(left, right)

    case left.type(@source_tdcs)
    when :boolean
      booleans_for_select = [[t('utils.yes'), constant(true).to_json], [t('utils.no'), constant(false).to_json]]

      if right_invalid
        booleans_for_select = empty_target_for_select + booleans_for_select
      end

      select_tag(
        input_name_for('value'),
        options_for_select(booleans_for_select, right.to_json),
        id: input_id_for('value', row_index),
        class: { 'fr-select': true, alert: right_invalid }
      )
    when :empty
      select_tag(
        input_name_for('value'),
        options_for_select(empty_target_for_select),
        id: input_id_for('value', row_index),
        class: 'fr-select'
      )
    when :enum, :enums, :commune_enum, :epci_enum, :departement_enum, :address
      enums_for_select = left.options(@source_tdcs, operator_name)

      if right_invalid
        enums_for_select = empty_target_for_select + enums_for_select
      end

      select_tag(
        input_name_for('value'),
        options_for_select(enums_for_select, right.value),
        id: input_id_for('value', row_index),
        class: { 'fr-select': true, alert: right_invalid }
      )
    when :number
      text_field_tag(
        input_name_for('value'),
        right.value,
        required: true,
        id: input_id_for('value', row_index),
        class: { 'fr-select': true, alert: right_invalid }
      )
    else
      text_field_tag(input_name_for('value'), '', id: input_id_for('value', row_index), class: 'fr-input')
    end
  end

  def current_right_valid?(left, right)
    Logic.compatible_type?(left, right, @source_tdcs)
  end

  def add_condition_tag
    tag.button(
      t('.add_condition'),
      formaction: add_condition_path,
      formnovalidate: true,
      class: 'fr-btn fr-btn--secondary fr-btn--sm fr-icon-add-circle-line fr-btn--icon-left'
    )
  end

  def delete_condition_tag(row_index)
    tag.button(
      class: "fr-btn fr-btn--sm fr-btn--tertiary fr-icon-delete-line",
      title: t('.remove_a_row'),
      formaction: delete_condition_path(row_index),
      formmethod: 'delete',
      formnovalidate: true
    )
  end

  def render?
    @condition.present? || available_targets_for_select.any?
  end

  def input_name_for(name)
    "#{input_prefix}[rows][][#{name}]"
  end
end
