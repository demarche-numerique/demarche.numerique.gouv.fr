# frozen_string_literal: true

# Single owner of the rule "a drop-down value must be one of the configured
# options": the AR validation of both drop-down champs and the prefill
# screening go through it, so the allowed set of each mode is computed once.
class DropDownOptionsValidator < ActiveModel::Validator
  # Whether every value belongs to the options: the configured options for a
  # simple list, the items of the referentiel for an advanced one (checked
  # live, in one indexed query, whatever the size of the referentiel).
  def self.allowed?(values, type_de_champ)
    values = values.uniq
    if type_de_champ.drop_down_advanced?
      referentiel = type_de_champ.referentiel
      return false if referentiel.nil?

      referentiel.items.where(id: values).pluck(:id).map(&:to_s).sort == values.sort
    else
      (values - type_de_champ.drop_down_options).empty?
    end
  end

  # Pure function of (values, type_de_champ) shared with the prefill
  # screening. A list accepting "other" takes any value, so the rule does not
  # apply to it. Returns [error_key, details] pairs.
  def self.violations(values, type_de_champ)
    values = values.compact_blank
    return [] if values.empty? || type_de_champ.drop_down_other?

    allowed?(values, type_de_champ) ? [] : [[:not_in_options, {}]]
  end

  def validate(champ)
    self.class.violations(champ.selected_values, champ.type_de_champ).each do |error, details|
      champ.errors.add(:value, error, **details)
    end
  end
end
