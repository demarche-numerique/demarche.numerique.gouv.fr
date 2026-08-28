# frozen_string_literal: true

describe Logic::PossibleValues::Number do
  it 'is a value: equal domains are one hash key' do
    integer = described_class.new(integer: true)

    expect({ integer.restrict(Logic::GreaterThan, 2) => true }).to have_key(integer.restrict(Logic::GreaterThanEq, 3))
    expect(integer.restrict(Logic::GreaterThan, 2)).not_to eq(described_class.new(integer: false).restrict(Logic::GreaterThan, 2))
  end

  def restrict(values, comparisons) = comparisons.reduce(values) { |d, (operator, value)| d.restrict(operator, value) }

  shared_examples 'a numeric champ' do |integer:, cases:|
    let(:values) { described_class.new(integer:) }

    cases.each do |comparisons, empty|
      it "#{comparisons.map { |op, v| "#{op.name.demodulize} #{v}" }.join(' and ')} is #{empty ? 'contradictory' : 'possible'}" do
        expect(restrict(values, comparisons).empty?).to be(empty)
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

  describe '.for' do
    def tdc(type, **options) = build(:"type_de_champ_#{type}", options:)

    it 'starts unlimited on a champ without validation' do
      values = described_class.for(tdc(:integer_number))

      expect(values.limits).to be_nil
      expect(values.restrict(Logic::GreaterThan, 10**9)).not_to be_empty
    end

    it 'starts at zero on a positive champ' do
      values = described_class.for(tdc(:integer_number, positive_number: '1'))

      expect(values.limits).to eq(min: 0, max: nil)
      expect(values.restrict(Logic::LessThan, 0)).to be_empty
      expect(values.restrict(Logic::Eq, 0)).not_to be_empty
    end

    it 'starts within the range, both ends included' do
      values = described_class.for(tdc(:decimal_number, range_number: '1', min_number: '2.5', max_number: '18'))

      expect(values.limits).to eq(min: 2.5, max: 18.0)
      expect(values.restrict(Logic::Eq, 18)).not_to be_empty
      expect(values.restrict(Logic::GreaterThan, 18)).to be_empty
      expect(values.restrict(Logic::LessThan, 2.5)).to be_empty
    end

    it 'keeps the tighter of positive and range' do
      expect(described_class.for(tdc(:integer_number, positive_number: '1', range_number: '1', min_number: '3')).limits).to eq(min: 3, max: nil)
      expect(described_class.for(tdc(:integer_number, positive_number: '1', range_number: '1', min_number: '-3')).limits).to eq(min: 0, max: nil)
    end

    it 'ignores the range when it is switched off' do
      expect(described_class.for(tdc(:integer_number, range_number: '0', min_number: '2', max_number: '18')).limits).to be_nil
    end

    it 'reads a bound the way the validator does' do
      values = described_class.for(tdc(:integer_number, range_number: '1', min_number: '', max_number: '4.9'))

      expect(values.limits).to eq(min: nil, max: 4)
      expect(values.restrict(Logic::GreaterThan, 4)).to be_empty
    end

    it 'can forget its limits' do
      values = described_class.for(tdc(:integer_number, range_number: '1', max_number: '5'))

      expect(values.unlimited.limits).to be_nil
      expect(values.unlimited.restrict(Logic::GreaterThan, 5)).not_to be_empty
    end
  end

  it_behaves_like 'a numeric champ', integer: false, cases: [
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

  it_behaves_like 'a numeric champ', integer: true, cases: [
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
    let(:values) { described_class.new(integer: false) }

    include_examples 'possible values regions', [[Logic::GreaterThan, 3], [Logic::LessThan, 2], [Logic::Eq, 3], [Logic::NotEq, 5]]

    it 'cuts at every constant' do
      regions = values.regions([[Logic::GreaterThan, 3], [Logic::LessThan, 2]])

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
      expect(values.regions([[Logic::Eq, 'abc']])).to eq([values])
    end

    it 'is the whole values without comparisons' do
      expect(values.regions([])).to eq([values])
    end
  end
end
