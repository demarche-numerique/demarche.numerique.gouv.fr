# frozen_string_literal: true

# Regions partition the values so that every comparison is either wholly true or
# wholly false on each of them.
RSpec.shared_examples 'possible values regions' do |comparisons|
  it 'are atomic with respect to the comparisons' do
    regions = values.regions(comparisons)

    expect(regions).not_to be_empty
    expect(regions).to all(satisfy { !it.empty? })

    regions.product(comparisons).each do |region, (operator, value)|
      restricted = region.restrict(operator, value)

      expect(restricted.empty? || restricted == region).to be(true), "#{operator.name} #{value} splits #{region.inspect}"
    end
  end

  it 'are no more than max_regions' do
    expect(values.regions(comparisons).size).to be <= values.max_regions(comparisons)
    expect(values.regions([]).size).to be <= values.max_regions([])
  end
end
