# frozen_string_literal: true

describe Logic::Domain::Number do
  it 'is a value: equal domains are one hash key' do
    integer = described_class.new(integer: true)

    expect({ integer.restrict(Logic::GreaterThan, 2) => true }).to have_key(integer.restrict(Logic::GreaterThanEq, 3))
    expect(integer.restrict(Logic::GreaterThan, 2)).not_to eq(described_class.new(integer: false).restrict(Logic::GreaterThan, 2))
  end

  def restrict(domain, atoms) = atoms.reduce(domain) { |d, (operator, value)| d.restrict(operator, value) }

  shared_examples 'a number domain' do |integer:, cases:|
    let(:domain) { described_class.new(integer:) }

    cases.each do |atoms, empty|
      it "#{atoms.map { |op, v| "#{op.name.demodulize} #{v}" }.join(' and ')} is #{empty ? 'contradictory' : 'satisfiable'}" do
        expect(restrict(domain, atoms).empty?).to be(empty)
      end
    end
  end

  it { expect(described_class.new(integer: false)).not_to be_empty }

  it 'ignores non numeric constants' do
    expect(described_class.new(integer: true).restrict(Logic::Eq, 'abc')).not_to be_empty
    expect(described_class.new(integer: true).restrict(Logic::Eq, '10').restrict(Logic::Eq, 11)).not_to be_empty
  end

  it 'ignores operators that do not apply to numbers' do
    expect(described_class.new(integer: true).restrict(Logic::IncludeOperator, 1)).not_to be_empty
  end

  it_behaves_like 'a number domain', integer: false, cases: [
    [[[Logic::Eq, 2], [Logic::Eq, 2]], false],
    [[[Logic::Eq, 2], [Logic::Eq, 3]], true],
    [[[Logic::Eq, 2], [Logic::NotEq, 2]], true],
    [[[Logic::Eq, 2], [Logic::NotEq, 3]], false],
    [[[Logic::GreaterThan, 3], [Logic::LessThan, 2]], true],
    [[[Logic::GreaterThan, 2], [Logic::LessThan, 3]], false],
    [[[Logic::GreaterThan, 2.5], [Logic::LessThan, 2.7]], false],
    [[[Logic::GreaterThan, 2], [Logic::LessThan, 2]], true],
    [[[Logic::GreaterThanEq, 2], [Logic::LessThanEq, 2]], false],
    [[[Logic::GreaterThanEq, 2], [Logic::LessThan, 2]], true],
    [[[Logic::GreaterThan, 2], [Logic::LessThanEq, 2]], true],
    [[[Logic::GreaterThan, 2], [Logic::Eq, 2]], true],
    [[[Logic::GreaterThanEq, 2], [Logic::Eq, 2]], false],
    [[[Logic::LessThan, 2], [Logic::Eq, 2]], true],
    [[[Logic::GreaterThan, 2], [Logic::GreaterThan, 3]], false],
    [[[Logic::NotEq, 2], [Logic::NotEq, 3]], false],
    [[[Logic::GreaterThan, 1], [Logic::LessThan, 3], [Logic::NotEq, 2]], false],
    [[[Logic::GreaterThanEq, 2], [Logic::LessThanEq, 2], [Logic::NotEq, 2]], true],
    [[[Logic::LessThanEq, -1], [Logic::GreaterThanEq, 0]], true],
    [[[Logic::LessThanEq, -1], [Logic::GreaterThanEq, -1.5]], false],
  ]

  it_behaves_like 'a number domain', integer: true, cases: [
    [[[Logic::GreaterThan, 2], [Logic::LessThan, 3]], true],
    [[[Logic::GreaterThan, 2], [Logic::LessThan, 4]], false],
    [[[Logic::GreaterThan, 1], [Logic::LessThan, 3], [Logic::NotEq, 2]], true],
    [[[Logic::GreaterThan, 1], [Logic::LessThan, 4], [Logic::NotEq, 2]], false],
    [[[Logic::GreaterThanEq, 2], [Logic::LessThanEq, 2]], false],
    [[[Logic::GreaterThan, 2.5], [Logic::LessThan, 3.5]], false],
    [[[Logic::GreaterThan, 2.5], [Logic::LessThan, 2.9]], true],
    [[[Logic::GreaterThanEq, 2.5], [Logic::LessThanEq, 2.9]], true],
    [[[Logic::GreaterThanEq, 3.0], [Logic::LessThanEq, 3.0]], false],
    [[[Logic::Eq, 2], [Logic::NotEq, 2.5]], false],
    [[[Logic::Eq, 2.5]], true],
    [[[Logic::GreaterThan, 2], [Logic::NotEq, 3], [Logic::LessThan, 4]], true],
    [[[Logic::GreaterThan, 2], [Logic::NotEq, 3], [Logic::LessThan, 5]], false],
  ]

  describe '#regions' do
    let(:domain) { described_class.new(integer: false) }

    include_examples 'domain regions', [[Logic::GreaterThan, 3], [Logic::LessThan, 2], [Logic::Eq, 3], [Logic::NotEq, 5]]

    it 'cuts at every constant' do
      regions = domain.regions([[Logic::GreaterThan, 3], [Logic::LessThan, 2]])

      expect(regions.size).to eq(5)
      expect(regions.map { it.restrict(Logic::GreaterThan, 3).empty? }).to eq([true, true, true, true, false])
      expect(regions.map { it.restrict(Logic::LessThan, 2).empty? }).to eq([true, true, false, true, true])
    end

    it 'drops the regions integers leave empty' do
      regions = described_class.new(integer: true).regions([[Logic::GreaterThan, 2], [Logic::LessThan, 3]])

      expect(regions.size).to eq(4) # 2, 3, < 2, > 3
    end

    it 'cuts integers at a decimal without a region for it' do
      regions = described_class.new(integer: true).regions([[Logic::GreaterThan, 2.5]])

      expect(regions.size).to eq(2) # <= 2, >= 3
      expect(regions.map { it.restrict(Logic::GreaterThan, 2.5).empty? }).to eq([true, false])
    end

    it 'ignores constants that are not numbers' do
      expect(domain.regions([[Logic::Eq, 'abc']])).to eq([domain])
    end

    it 'is the whole domain without atoms' do
      expect(domain.regions([])).to eq([domain])
    end
  end

  describe '#union' do
    def number(integer, *atoms) = atoms.reduce(described_class.new(integer:)) { |d, (op, v)| d.restrict(op, v) }

    it 'merges touching intervals' do
      expect(number(true, [Logic::LessThan, 18]).union(number(true, [Logic::Eq, 18])).to_s).to eq('18 ou moins')
      expect(number(true, [Logic::Eq, 18]).union(number(true, [Logic::GreaterThan, 18], [Logic::LessThan, 65])).to_s).to eq('de 18 à 64')
      expect(number(false, [Logic::LessThan, 18]).union(number(false, [Logic::GreaterThanEq, 18])).to_s).to eq('toute valeur')
      expect(number(false, [Logic::LessThan, 18]).union(number(false, [Logic::GreaterThan, 18])).to_s).to eq('moins de 18 ou plus de 18')
    end

    it 'keeps separate intervals apart' do
      expect(number(true, [Logic::LessThan, 10]).union(number(true, [Logic::GreaterThan, 20])).to_s).to eq('9 ou moins ou 21 ou plus')
    end

    it 'does not merge with other kinds' do
      expect(number(true).union(Logic::Domain::Blank)).to be_nil
    end
  end

  describe '#to_s' do
    it 'describes integers with closed bounds' do
      domain = described_class.new(integer: true)

      expect(domain.to_s).to eq('toute valeur')
      expect(domain.restrict(Logic::LessThan, 18).to_s).to eq('17 ou moins')
      expect(domain.restrict(Logic::LessThanEq, 18).to_s).to eq('18 ou moins')
      expect(domain.restrict(Logic::GreaterThan, 64).to_s).to eq('65 ou plus')
      expect(domain.restrict(Logic::Eq, 18).to_s).to eq('18')
      expect(domain.restrict(Logic::NotEq, 18).to_s).to eq('17 ou moins ou 19 ou plus')
    end

    it 'describes decimals with open bounds' do
      domain = described_class.new(integer: false)

      expect(domain.restrict(Logic::LessThan, 18).to_s).to eq('moins de 18')
      expect(domain.restrict(Logic::GreaterThan, 2.5).to_s).to eq('plus de 2.5')
      expect(domain.restrict(Logic::GreaterThan, 2).restrict(Logic::LessThan, 3).to_s).to eq('entre 2 et 3')
      expect(domain.restrict(Logic::GreaterThanEq, 2).restrict(Logic::LessThanEq, 3).to_s).to eq('de 2 à 3')
    end
  end
end
