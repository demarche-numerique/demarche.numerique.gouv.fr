# frozen_string_literal: true

class Champs::LinkedDropDownListChamp < ChampData
  delegate :primary_options, :secondary_options, to: :type_de_champ

  def primary_value
    if type_de_champ.champ_blank?(self)
      ''
    else
      JSON.parse(value)[0]
    end
  end

  def secondary_value
    if type_de_champ.champ_blank?(self)
      ''
    else
      JSON.parse(value)[1]
    end
  end

  def primary_value=(value)
    if value.blank?
      pack_value("", "")
    else
      new_secondary_value = secondary_options[value]&.include?(secondary_value) ? secondary_value : ""
      pack_value(value, new_secondary_value)
    end
  end

  def secondary_value=(value)
    new_secondary_value = secondary_options[primary_value]&.include?(value) ? value : ""
    pack_value(primary_value, new_secondary_value)
  end

  def main_value_name
    :primary_value
  end

  def search_terms
    [primary_value, secondary_value]
  end

  def has_secondary_options_for_primary?
    primary_value.present? && secondary_options[primary_value]&.any?(&:present?)
  end

  def libelle_for_error
    if primary_value.blank?
      libelle
    else
      drop_down_secondary_libelle.presence || I18n.t('shared.champs.linked_drop_down_list.secondary_default_libelle')
    end
  end

  # Validate each sub-input independently so the error targets the right select,
  # like AddressChamp does for its sub-fields. The primary is the main value
  # (anchored on :value); only the secondary needs its own attribute.
  def validate_completed
    return if !mandatory?

    if primary_value.blank?
      errors.add(:value, :missing)
    elsif has_secondary_options_for_primary? && secondary_value.blank?
      errors.add(:secondary_value, :missing)
    end
  end

  private

  def pack_value(primary, secondary)
    self.value = JSON.generate([primary, secondary])
  end
end
