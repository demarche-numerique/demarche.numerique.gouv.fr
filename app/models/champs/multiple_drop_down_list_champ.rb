# frozen_string_literal: true

class Champs::MultipleDropDownListChamp < Champ
  store_accessor :value_json, :referentiels
  validate :values_are_in_options, if: -> { value.present? && validate_champ_value? }
  before_save :store_referentiels, if: :drop_down_advanced?

  THRESHOLD_NB_OPTIONS_AS_CHECKBOX = 5

  def search_terms
    selected_options
  end

  def selected_options
    value.blank? ? [] : JSON.parse(value)
  end

  def render_as_checkboxes?
    drop_down_options.size <= THRESHOLD_NB_OPTIONS_AS_CHECKBOX
  end

  def html_label?
    !render_as_checkboxes?
  end

  def legend_label?
    true
  end

  def single_checkbox?
    render_as_checkboxes?
  end

  def focusable_input_id(attribute = :value)
    render_as_checkboxes? ? checkbox_id(drop_down_options.first) : input_id
  end

  def checkbox_id(value)
    "#{input_id}-#{Digest::MD5.hexdigest(value)}"
  end

  def checkbox_label_id(value)
    "#{checkbox_id(value)}-label"
  end

  def value=(value)
    return super(nil) if value.blank?

    values = if value.is_a?(Array)
      value
    elsif value.starts_with?('[')
      JSON.parse(value) rescue selected_options + [value] # value may start by [ without being a real JSON value
    else
      selected_options + [value]
    end.uniq.without('')

    if values.empty?
      super(nil)
    else
      super(values.to_json)
    end
  end

  def store_referentiels
    self.referentiels = referentiels_from(value)
  end

  def referentiel_items_selected?
    referentiels.present?
  end

  def referentiels_items_column_values
    return [] if referentiels.nil?
    referentiels.map do |referentiel|
      referentiel_headers.map { |(header, path)| [header, referentiel.second.dig('data', 'row', path)] }
    end
  end

  def referentiels_items_user_values
    referentiels_items_column_values.map { |referentiel| referentiel.first.second }
  end

  def referentiel_headers
    return [] if referentiels&.blank? || referentiels&.first&.blank?

    headers = referentiels.first.second&.dig('data', 'headers') || []
    headers.map { |header| [header, Referentiel.header_to_path(header)] }
  end

  private

  def referentiels_from(value)
    return if value.blank?
    values = JSON.parse(value)
    referentiel_items = type_de_champ.referentiel.items.where(id: values)

    # When changing tdc type or simple/advanced mode, champ value is not an item id
    if referentiel_items.empty?
      self.value = nil
    else
      referentiel_items.each_with_object({}) do |item, referentiels_data|
        headers = item.referentiel.headers
        referentiels_data[item.id] = { data: item.data.merge(headers:) }
      end
    end
  rescue JSON::ParserError
    {}
  end

  def values_are_in_options
    json = selected_options.compact_blank
    return if json.empty?
    return if (json - drop_down_options).empty? && !drop_down_advanced?
    return if drop_down_advanced? && referentiels.present? && (json - referentiels.keys).empty?

    errors.add(:value, :not_in_options)
  end
end
