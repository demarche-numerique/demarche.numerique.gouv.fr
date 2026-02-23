# frozen_string_literal: true

class Instructeurs::ClearFilterButtonsComponent < ApplicationComponent
  def initialize(filters:, procedure_presentation:, statut:)
    @filters = filters
    @procedure_presentation = procedure_presentation
    @statut = statut
  end

  def call
    items = filters_by_family
    items << clear_all_filters_link if filters_by_family.count > 2
    safe_join(items)
  end

  private

  def filters_by_family
    @filters
      .reject(&:empty_filter?)
      .flat_map do |filter|
        if filter.filter_values.empty?
          [filter_form(filter, nil)]
        else
          filter.filter_values.map { |value| filter_form(filter, value) }
        end
      end
  end

  def clear_all_filters_link
    button_to(
      clear_all_filters_instructeur_procedure_presentation_path(@procedure_presentation),
      class: 'fr-btn fr-btn--tertiary-no-outline fr-btn--sm',
      params: {
        statut: @statut,
      },
      form: { data: { turbo: true } },
      form_class: 'inline'
    ) do
      t('.clear_all_filters')
    end
  end

  def filter_form(filter, value)
    # Create new filter with the specific value removed
    new_filter = if value.nil?
      # If value is nil, clear the entire filter
      filter.empty_filter
    else
      new_filter_values = filter.filter_values - [value]
      if new_filter_values.empty?
        filter.empty_filter
      else
        { operator: filter.filter_operator, value: new_filter_values }
      end
    end

    button_to(
      update_filter_instructeur_procedure_presentation_path(@procedure_presentation),
      id: "clear-filter-button-#{filter.id}-#{value}".parameterize,
      class: 'fr-tag fr-tag--dismiss fr-tag--sm',
      params: {
        filter_key: filter.id,
        filter: { id: filter.column.id, filter: new_filter },
        statut: @statut,
      }.compact,
      form: { data: { turbo: true } },
      form_class: 'inline'
    ) do
      button_content(filter, value)
    end
  end

  def button_content(filter, value)
    if value.nil?
      "#{filter.human_label.truncate(50)} : #{human_operator(filter.filter_operator)}"
    else
      "#{filter.human_label.truncate(50)} : #{human_value(filter, value)}"
    end
  end

  def human_value(filter_column, value)
    column_type = filter_column.column.type

    processed_value = if column_type == :date || column_type == :datetime
      helpers.try_parse_format_date(value)
    else
      filter_column.column.label_for_value(value)
    end

    [human_operator(filter_column.filter_operator), processed_value].compact_blank.join(' ')
  end

  def human_operator(operator)
    return "" if operator.in?(["in", "match"])

    t(".operators.#{operator}")
  end
end
