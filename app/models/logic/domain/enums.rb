# frozen_string_literal: true

# A multiple-choice champ holds a subset of its options; the atoms only ever
# require an option to be selected or not, so the domain is the pair of those
# requirements, contradictory as soon as one option is in both, or as soon as
# every option is excluded: a filled champ has at least one selected.
class Logic::Domain::Enums < Data.define(:options, :must_include, :must_exclude)
  def initialize(options:, must_include: Set.new, must_exclude: Set.new) = super(options: options.to_set, must_include:, must_exclude:)

  def empty? = must_include.intersect?(must_exclude) || (options.any? && options.subset?(must_exclude))

  # Every combination of the options the atoms mention being selected or not.
  def regions(atoms)
    mentioned = atoms.map(&:last).uniq

    (0..mentioned.size).flat_map { |n| mentioned.combination(n).to_a }.map do |selected|
      with(must_include: must_include | selected, must_exclude: must_exclude | (mentioned - selected))
    end.reject(&:empty?)
  end

  # Exponential in the mentioned options: check it before calling `regions`.
  def max_regions(atoms) = 2**atoms.map(&:last).uniq.size

  def restrict(operator_class, value)
    case operator_class.name
    when Logic::IncludeOperator.name then with(must_include: must_include | [value], must_exclude: must_exclude)
    when Logic::ExcludeOperator.name then with(must_include: must_include, must_exclude: must_exclude | [value])
    else self
    end
  end
end
