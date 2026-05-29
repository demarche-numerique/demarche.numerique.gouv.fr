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
    current_target_valid = sources_by_section
      .values
      .flat_map { it.map(&:last) }
      .include?(targeted_champ)

    selected_target = current_target_valid ? targeted_champ : empty

    select_tag(
      input_name_for('targeted_champ'),
      target_options_html(sources_by_section, selected_target),
      onchange: "this.form.action = this.form.action + '/change_targeted_champ?row_index=#{row_index}'",
      id: input_id_for('targeted_champ', row_index),
      class: { 'fr-select': true, alert: !current_target_valid }
    )
  end

  def target_options_html(sources_by_section, selected_target)
    options = [option_tag(t('.select'), empty, selected_target)]

    sources_by_section.each do |section, sources|
      options << content_tag(:option, section.libelle, disabled: true) if section.present?
      sources.each { |label, source| options << option_tag(label, source, selected_target) }
    end

    safe_join(options)
  end

  def option_tag(label, source, selected)
    content_tag(:option, label, value: source.to_json, selected: source == selected)
  end

  def empty_target_for_select
    [[t('.select'), empty.to_json]]
  end

  def column_mode?
    feature_enabled?(:column_conditions) && !@champ_value_in_condition
  end

  def sources_by_section
    @sources_by_section ||= index_by_top_section(@source_tdcs)
      .transform_values { |tdcs| to_sources(tdcs) }
      .compact_blank
  end

  def index_by_top_section(tdcs)
    last_section = nil
    tdcs.each_with_object(Hash.new { |h, k| h[k] = [] }) do |tdc, h|
      if tdc.header_section? && tdc.header_section_level_value == 1
        last_section = tdc
      else
        h[last_section] << tdc
      end
    end
  end

  def to_sources(tdcs) = column_mode? ? to_column_values(tdcs) : to_champ_values(tdcs)

  SUPPORTED_TYPES = [:integer, :decimal, :enum, :enums, :boolean].freeze

  def to_column_values(tdcs)
    tdcs
      .reject(&:repetition?)
      .flat_map { it.columns(procedure_id: @procedure.id) }
      .filter(&:filterable)
      .filter { it.type.in?(SUPPORTED_TYPES) }
      .map { |column| [column.label, column_value(column)] }
  end

  def to_champ_values(tdcs)
    tdcs
      .filter(&:conditionable?)
      .map { |tdc| [tdc.libelle, champ_value(tdc.stable_id)] }
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
    @condition.present? || sources_by_section.any?
  end

  def input_name_for(name)
    "#{input_prefix}[rows][][#{name}]"
  end
end
