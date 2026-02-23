# frozen_string_literal: true

class Instructeurs::CustomizeFiltersComponent < ApplicationComponent
  attr_reader :procedure_presentation, :statut, :filters_columns, :apply_to_all_tabs

  def initialize(procedure_presentation:, statut:, filters_columns:, apply_to_all_tabs: false)
    @procedure_presentation = procedure_presentation
    @statut = statut
    @filters_columns = filters_columns
    @apply_to_all_tabs = apply_to_all_tabs
  end

  def id
    "customize-filters-component"
  end

  def filters_selects
    [
      {
        label: t('.file_information'),
        items: dossier_filter_items,
      },
      {
        label: t('.user_information'),
        items: usager_filter_items,
      },
      {
        label: t('.user_form'),
        items: form_filter_items,
      },
      {
        label: t('.private_annotations'),
        items: annotation_filter_items,
      },
    ].filter { _1[:items].any? }
  end

  def filter_action_button(filter_column:, icon:, text:, filters_columns_array:, disabled: false)
    form_with(
      url: refresh_filters_instructeur_procedure_presentation_path(@procedure_presentation),
      method: :post,
      data: { turbo: true, turbo_force: :server },
      class: 'inline'
    ) do |form|
      safe_join([
        *filters_columns_array.map { |filter| form.hidden_field "filters_columns[]", value: filter.id },
        form.hidden_field("statut", value: @statut),
        form.hidden_field("apply_to_all_tabs", value: @apply_to_all_tabs ? '1' : '0'),
        form.button(text, type: :submit, class: "fr-btn fr-btn--tertiary-no-outline fr-icon-#{icon}", disabled: disabled),
      ])
    end
  end

  def delete_button(filter_column)
    filter_action_button(
      filter_column: filter_column,
      icon: 'delete-line',
      text: t('.delete_filter', filter_label: filter_column.human_label),
      filters_columns_array: filters_columns.filter { _1.id != filter_column.id }
    )
  end

  def move_up_button(filter_column)
    current_index = filters_columns.index(filter_column)
    return nil if current_index.nil?

    can_move_up = !current_index.zero?
    reordered_columns = if can_move_up
      columns = filters_columns.dup
      columns[current_index], columns[current_index - 1] = columns[current_index - 1], columns[current_index]
      columns
    else
      filters_columns
    end

    filter_action_button(
      filter_column: filter_column,
      icon: 'arrow-up-line',
      text: t('.move_up_filter', filter_label: filter_column.human_label),
      filters_columns_array: reordered_columns,
      disabled: !can_move_up
    )
  end

  def move_down_button(filter_column)
    current_index = filters_columns.index(filter_column)
    return nil if current_index.nil?

    can_move_down = current_index != filters_columns.length - 1
    reordered_columns = if can_move_down
      columns = filters_columns.dup
      columns[current_index], columns[current_index + 1] = columns[current_index + 1], columns[current_index]
      columns
    else
      filters_columns
    end

    filter_action_button(
      filter_column: filter_column,
      icon: 'arrow-down-line',
      text: t('.move_down_filter', filter_label: filter_column.human_label),
      filters_columns_array: reordered_columns,
      disabled: !can_move_down
    )
  end

  def procedure
    @procedure_presentation.procedure
  end

  def dossier_filter_items
    {
      "-- #{t('.file_section')} --" => procedure.dossier_filterable_columns,
      "-- #{t('.instructors_section')} --" => procedure.instructeurs_filterable_columns,
    }.transform_values { it.map { [_1.human_label, _1.id] } }
  end

  def disabled_items
    @disabled_items ||= filters_columns.map(&:id)
  end

  def filters_in_hidden_inputs(form, form_prefix, include_apply_to_all_tabs: true)
    # form_prefix is used to avoid id conflicts with other forms on the page
    inputs = [
      *filters_columns.map { |filter| form.hidden_field "filters_columns[]", value: filter.id, id: "#{form_prefix}-filter-#{filter.id.parameterize}" },
      form.hidden_field("statut", value: @statut, id: "#{form_prefix}-statut"),
    ]
    inputs << form.hidden_field("apply_to_all_tabs", value: @apply_to_all_tabs ? '1' : '0', id: "#{form_prefix}-apply-to-all-tabs") if include_apply_to_all_tabs
    safe_join(inputs)
  end

  def usager_filter_items
    procedure.usager_filterable_columns.map { [_1.human_label, _1.id] }
  end

  def form_filter_items
    procedure.form_filterable_columns.map { [_1.human_label, _1.id] }
  end

  def annotation_filter_items
    procedure.annotation_privees_filterable_columns.map { [_1.human_label, _1.id] }
  end
end
