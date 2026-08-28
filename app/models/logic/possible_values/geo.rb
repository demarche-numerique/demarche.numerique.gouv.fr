# frozen_string_literal: true

# Every geographic champ (departement, commune, EPCI, address) resolves to a
# departement code, and a region is a fixed set of departements, so what it
# can hold is a set of departement codes. Expanding regions onto that
# common alphabet is what makes `en Bretagne and à Paris` a plain empty set
# intersection, with no knowledge of the geography left in the check.
class Logic::PossibleValues::Geo < Data.define(:codes)
  def initialize(codes: APIGeoService.departements.map { it[:code] }) = super(codes: codes.to_set)

  def empty? = codes.empty?

  def restrict(operator_class, value)
    case operator_class.name
    when Logic::Eq.name, Logic::InDepartementOperator.name then self.class.new(codes & [value])
    when Logic::NotEq.name, Logic::NotInDepartementOperator.name then self.class.new(codes - [value])
    when Logic::InRegionOperator.name then self.class.new(codes & departements_in_region(value))
    when Logic::NotInRegionOperator.name then self.class.new(codes - departements_in_region(value))
    else self
    end
  end

  private

  def departements_in_region(region_code)
    APIGeoService.departements.filter { it[:region_code] == region_code }.map { it[:code] }
  end
end
