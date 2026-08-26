# frozen_string_literal: true

class TypesDeChamp::PrefillMultipleDropDownList < TypesDeChamp::PrefillDropDownList
  def example_value
    return nil if all_possible_values.empty?
    return all_possible_values.first if all_possible_values.one?

    [all_possible_values.first, all_possible_values.second]
  end

  private

  def screened_value(champ, value)
    return nil if !acceptable_prefill_value?(value)

    values = Champs::MultipleDropDownListChamp.parse_values(value)

    # Advanced lists store item ids: resolve each input (id or label) and keep
    # only the ones matching an item, serialized like the champ setter expects.
    if drop_down_advanced?
      resolved = values.filter_map { referentiel&.resolve_item_id(_1) }
      return resolved.empty? ? nil : resolved.to_json
    end

    return nil if DropDownOptionsValidator.violations(values, self).any?

    value
  end
end
