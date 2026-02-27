# frozen_string_literal: true

class Champs::DropDownListChamp < Champ
  store_accessor :value_json, :other, :referentiel
  THRESHOLD_NB_OPTIONS_AS_RADIO = 5
  THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE = 20
  OTHER = '__other__'
  delegate :options_without_empty_value_when_mandatory, to: :type_de_champ
  validate :validate_value_is_in_options, if: -> { validate_champ_value? && !(value.blank? || drop_down_other?) }
  before_save :store_referentiel, if: :drop_down_advanced?

  def render_as_radios?
    drop_down_options.size <= THRESHOLD_NB_OPTIONS_AS_RADIO
  end

  def render_as_combobox?
    drop_down_options.size >= THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE
  end

  def focusable_input_id(attribute = :value)
    render_as_radios? ? radio_id(drop_down_options.first) : input_id
  end

  def radio_id(value)
    "#{input_id}-#{Digest::MD5.hexdigest(value.to_s)}"
  end

  def html_label?
    !render_as_radios?
  end

  def legend_label?
    render_as_radios?
  end

  def selected
    other? ? OTHER : value
  end

  def other?
    drop_down_other? && (other || value_from_user?)
  end

  def value_from_user?
    value.present? && !value_is_in_options?(value)
  end

  def value=(value)
    if value == OTHER
      self.other = true
      write_attribute(:value, nil)
    else
      self.other = false
      write_attribute(:value, value)
    end
  end

  def store_referentiel
    if other?
      self.referentiel = nil
    else
      self.referentiel = referentiel_from(value)
    end
  end

  def value_other=(value)
    if other?
      write_attribute(:value, value)
    end
  end

  def value_other
    other? ? value : ""
  end

  def referentiel_item_selected?
    referentiel&.dig('data', 'row').present?
  end

  def referentiel_item_value(path)
    referentiel&.dig('data', 'row', path)
  end

  def referentiel_item_column_values
    return [] if referentiel.nil?
    referentiel_headers.map { |(header, path)| [header, referentiel_item_value(path)] }
  end

  def referentiel_headers
    headers = referentiel&.dig('data', 'headers') || []
    headers.map { [_1, Referentiel.header_to_path(_1)] }
  end

  private

  def referentiel_from(value)
    return if value.blank?

    referentiel_item = type_de_champ.referentiel.items.find_by(id: value)

    # When changing tdc type or simple/advanced mode, champ value is not an item id
    if referentiel_item.blank?
      self.value = nil
      return
    end

    headers = referentiel_item.referentiel.headers
    { data: referentiel_item.data.merge(headers:) }
  end

  def validate_value_is_in_options
    return if value_is_in_options?(value)
    errors.add(:value, :not_in_options)
  end
end
