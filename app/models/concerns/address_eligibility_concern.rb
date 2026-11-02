# frozen_string_literal: true

module AddressEligibilityConcern
  extend ActiveSupport::Concern

  TERRITORY_RULES = {
    departements: [Logic::NotInDepartementOperator, '$.department_code'],
    regions: [Logic::NotInRegionOperator, '$.region_code'],
  }.freeze

  # The departements and regions the form's only address (mandatory, always
  # shown) must lie in, when every ineligibility rule reads "département /
  # région is not …" and they are joined by "and"; nil otherwise.
  def address_eligible_territories
    return if !ineligibilite_enabled?

    address = sole_unconditional_address
    return if address.nil?

    matchers = territory_matchers(address)
    rules = ineligibilite_rules.is_a?(Logic::And) ? ineligibilite_rules.operands : [ineligibilite_rules]
    territories = rules.map do |rule|
      kind, _ = matchers.find { |_, operator, left| rule.instance_of?(operator) && rule.left == left }
      [kind, rule.right.value] if kind && rule.right.is_a?(Logic::Constant)
    end
    return if territories.empty? || territories.any?(&:nil?)

    TERRITORY_RULES.keys.index_with { |kind| territories.filter_map { |k, code| code if k == kind }.uniq }
  end

  private

  def sole_unconditional_address
    addresses = type_de_champs_for(scope: :public).filter(&:address?)
    address = addresses.first if addresses.one?

    address if address&.mandatory? && !address.condition? && parent_of(address).nil?
  end

  # [kind, operator, left term] of a "not in" rule, as the old editor
  # ("n'est pas dans le département") and the new one ("Département n'est pas") write it
  def territory_matchers(address)
    columns = address.columns(procedure_id: nil)

    TERRITORY_RULES.flat_map do |kind, (old_operator, jsonpath)|
      column = columns.find { it.try(:jsonpath) == jsonpath }
      [[kind, old_operator, champ_value(address.stable_id)], ([kind, Logic::NotEq, champ_column_value(column)] if column)].compact
    end
  end
end
