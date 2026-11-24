# frozen_string_literal: true

class Instructeurs::ColumnFilterValueComponent < ApplicationComponent
  attr_reader :filtered_column, :form, :instructeur_procedure, :groupe_instructeur_ids

  delegate :label, :date_range?, to: :filtered_column

  MAX_LABEL_LENGTH = 50

  def initialize(filtered_column:, form:, instructeur_procedure:, groupe_instructeur_ids:)
    @filtered_column = filtered_column
    @form = form
    @instructeur_procedure = instructeur_procedure
    @groupe_instructeur_ids = groupe_instructeur_ids
  end

  def id
    # unique id to avoid turbo-frame reload
    "#{filtered_column.id.parameterize}_column_filter_value_component"
  end

  def operator_hidden_field
    return nil if is_date?

    @form.hidden_field "filter[filter][operator]", value: 'match'
  end

  def column
    filtered_column&.column
  end

  def render_label
    return content_tag(:span, label) if !truncated_label?

    safe_join([
      content_tag(:span, label_text, title: label, aria: { hidden: true }),
      content_tag(:span, label, class: 'fr-sr-only'),
    ])
  end

  def value
    filtered_column&.filter_values
  end

  def operator
    filtered_column&.filter_operator || "match"
  end

  def column_filter_options
    @column_filter_options ||= build_column_filter_options
  end

  def build_column_filter_options
    options = case column
    when Columns::DossierLinkColumn
      column.options_for_dossiers(current_instructeur.dossiers)
    else
      column.filter_options(groupe_instructeur_ids)
    end

    if tdc_type.in?([TypeDeChamp.type_champs.fetch(:yes_no), TypeDeChamp.type_champs.fetch(:civilite)]) && !column.mandatory
      options << Column.not_filled_option
    end

    if column.column == 'notification_type'
      options.filter! do |_, type|
        DossierNotification::NON_CUSTOMISABLE_TYPE.include?(type) || @instructeur_procedure&.notification_preference_for(type) != 'none'
      end
    end

    options
  end

  def radio_button_options
    column_filter_options.map do |(opt_label, opt_value)|
      {
        label: opt_label,
        value: opt_value,
        checked: opt_value.to_s.in?(value),
        id: input_id(value: opt_value),
        data: { turbo_force: :server },
      }
    end
  end

  def date_filter_options
    [*FilteredColumn::OPERATORS_WITH_VALUE, 'this_week', 'this_month', 'this_year']
      .map { |operator| [t(".operators.#{operator}"), operator] }
  end

  def tdc_type
    column.tdc_type if column.respond_to?(:tdc_type)
  end

  def is_date?
    column&.type&.in?([:datetime, :date])
  end

  def is_operator_with_value?
    return true if !is_date?

    filtered_column.filter_operator.in?(FilteredColumn::OPERATORS_WITH_VALUE)
  end

  def selectable?
    column&.type&.in?([:enum, :enums])
  end

  # Without any value to suggest, the filter stays a plain text input.
  def suggestions? = column&.suggestions? && column_filter_options.present?

  def radio_buttons?
    column&.type&.in?([:boolean]) || tdc_type == TypeDeChamp.type_champs.fetch(:civilite) || (column.respond_to?(:table) && column.table == "individual" && column.column == "gender")
  end

  def react_props
    {
      trigger_id: input_id,
      label_id:,
      class_name: 'fr-mt-1w',
      name: 'filter[filter][value][]',
      items: column_filter_options,
      value: Array(filtered_column&.filter_values).map(&:to_s),
      placeholder: t('.multi_select_placeholder'),
    }
  end

  # Only a picked suggestion submits the filter: typed text waits for the search button.
  # The newline separator, which an input cannot hold, keeps the typed text in one value.
  def combobox_props
    {
      input_id:,
      label_id:,
      name: 'filter[filter][value][]',
      class_name: 'fr-mb-0',
      items: column_filter_options,
      selected_keys: Array(value).map(&:to_s),
      allows_custom_value: true,
      value_separator: "\n",
      placeholder: t('.search_placeholder'),
      data: { autosubmit_target: 'input' },
    }
  end

  def input_id(value: nil)
    ["value", filtered_column&.id, value].compact.join('_').parameterize
  end

  def label_id
    "#{input_id}_label"
  end

  private

  def type
    case column&.type
    when :datetime, :date
      'date'
    when :integer, :decimal
      'number'
    else
      'text'
    end
  end

  def label_text
    label.truncate(MAX_LABEL_LENGTH)
  end

  def truncated_label?
    label.length > MAX_LABEL_LENGTH
  end
end
