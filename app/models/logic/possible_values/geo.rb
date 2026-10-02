# frozen_string_literal: true

# Every geographic champ (departement, commune, EPCI, address) resolves to a
# departement code, and a region is a fixed set of departements, so what it
# can hold is a set of departement codes. Expanding regions onto that
# common alphabet is what makes `en Bretagne and à Paris` a plain empty set
# intersection, with no knowledge of the geography left in the check.
class Logic::PossibleValues::Geo < Data.define(:codes)
  DEPARTEMENT_OPERATORS = [Logic::Eq, Logic::NotEq, Logic::InDepartementOperator, Logic::NotInDepartementOperator].map(&:name)
  REGION_OPERATORS = [Logic::InRegionOperator, Logic::NotInRegionOperator].map(&:name)

  def initialize(codes: APIGeoService.departements.map { it[:code] }) = super(codes: codes.to_set)

  def empty? = codes.empty?

  # Every departement the comparisons mention on its own, the rest of every region
  # they mention, and all the other departements together.
  def regions(comparisons)
    departements = mentioned(comparisons, DEPARTEMENT_OPERATORS)
    regions = mentioned(comparisons, REGION_OPERATORS)

    singletons = departements.map { self.class.new(codes & [it]) }
    by_region = regions.map { self.class.new((codes & departements_in_region(it)) - departements) }
    rest = self.class.new(codes - departements - regions.flat_map { departements_in_region(it) })

    [*singletons, *by_region, rest].reject(&:empty?)
  end

  def max_regions(comparisons) = [mentioned(comparisons, DEPARTEMENT_OPERATORS).size + mentioned(comparisons, REGION_OPERATORS).size + 1, codes.size].min

  def limits = nil

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

  # Departements and regions are counted apart: a code can name one of each
  # (75 is Paris as a departement, Nouvelle-Aquitaine as a region).
  def mentioned(comparisons, operators) = comparisons.filter { operators.include?(it.first.name) }.map(&:last).uniq

  def departements_in_region(region_code) = APIGeoService.departements_by_region.fetch(region_code, [])
end
