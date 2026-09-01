# frozen_string_literal: true

# Every geographic champ (departement, commune, EPCI, address) resolves to a
# departement code, and a region is a fixed set of departements, so the domain
# is the set of departement codes still allowed.
class Logic::Domain::Geo < Data.define(:codes)
  DEPARTEMENT_OPERATORS = [Logic::Eq, Logic::NotEq, Logic::InDepartementOperator, Logic::NotInDepartementOperator].map(&:name)
  REGION_OPERATORS = [Logic::InRegionOperator, Logic::NotInRegionOperator].map(&:name)
  MAX_LISTED = 6

  def initialize(codes: APIGeoService.departements.map { it[:code] }) = super(codes: codes.to_set)

  def empty? = codes.empty?

  def union(other) = other.is_a?(self.class) ? self.class.new(codes | other.codes) : nil

  # As enumerated
  def sort_key = [0]

  # Whole regions by name, the remaining departements one by one, or just how
  # many when there are too many to list.
  def to_s(_type_de_champ = nil)
    return I18n.t('logic.domain.geo.all') if codes == self.class.new.codes

    remaining = codes.dup
    regions = APIGeoService.regions.filter_map do |region|
      departements = departements_in_region(region[:code])
      next if departements.empty? || !departements.all? { remaining.include?(it) }

      remaining -= departements
      region[:name]
    end

    return I18n.t('logic.domain.geo.count', count: codes.size) if regions.size + remaining.size > MAX_LISTED

    (regions + remaining.sort.map { "#{it} – #{APIGeoService.departement_name(it)}" }).join(', ')
  end

  # Every departement the atoms mention on its own, the rest of every region
  # they mention, and all the other departements together.
  def regions(atoms)
    departements = atoms.filter { DEPARTEMENT_OPERATORS.include?(it.first.name) }.map(&:last).uniq
    regions = atoms.filter { REGION_OPERATORS.include?(it.first.name) }.map(&:last).uniq

    singletons = departements.map { self.class.new(codes & [it]) }
    by_region = regions.map { self.class.new((codes & departements_in_region(it)) - departements) }
    rest = self.class.new(codes - departements - regions.flat_map { departements_in_region(it) })

    [*singletons, *by_region, rest].reject(&:empty?)
  end

  def max_regions(atoms) = [atoms.map(&:last).uniq.size + 1, codes.size].min

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

  def departements_in_region(region_code) = APIGeoService.departements_by_region.fetch(region_code, [])
end
