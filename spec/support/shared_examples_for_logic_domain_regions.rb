# frozen_string_literal: true

# Regions partition the domain so that every atom is either wholly true or
# wholly false on each of them.
RSpec.shared_examples 'domain regions' do |atoms|
  it 'are atomic with respect to the atoms' do
    regions = domain.regions(atoms)

    expect(regions).not_to be_empty
    expect(regions).to all(satisfy { !it.empty? })

    regions.product(atoms).each do |region, (operator, value)|
      restricted = region.restrict(operator, value)

      expect(restricted.empty? || restricted == region).to be(true), "#{operator.name} #{value} splits #{region.inspect}"
    end
  end

  it 'are no more than max_regions' do
    expect(domain.regions(atoms).size).to be <= domain.max_regions(atoms)
    expect(domain.regions([]).size).to be <= domain.max_regions([])
  end
end
