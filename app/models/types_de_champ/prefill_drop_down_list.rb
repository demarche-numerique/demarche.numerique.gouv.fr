# frozen_string_literal: true

class TypesDeChamp::PrefillDropDownList < TypesDeChamp::Prefill
  def all_possible_values
    if drop_down_other?
      [I18n.t("views.prefill_descriptions.edit.possible_values.drop_down_list_other_html")] + drop_down_options
    else
      drop_down_options
    end
  end

  def example_value
    all_possible_values.first
  end

  private

  # Advanced (referentiel-backed) lists store an item id, so a prefill input
  # given as a human label is resolved to its item id (the champ setter only
  # accepts ids). Simple lists are screened against their options; lists
  # accepting "other" take any value.
  def screened_value(champ, value)
    return nil if !value.is_a?(String)

    if drop_down_advanced?
      resolved = referentiel&.resolve_item_id(value)
      return resolved if resolved.present?
      return drop_down_other? ? value : nil
    end

    return nil if screenable? && DropDownOptionsValidator.violations([value], self).any?

    value
  end

  def screenable?
    drop_down_simple? && !drop_down_other?
  end
end
