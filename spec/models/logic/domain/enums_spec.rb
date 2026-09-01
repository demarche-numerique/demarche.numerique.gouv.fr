# frozen_string_literal: true

describe Logic::Domain::Enums do
  let(:domain) { described_class.new(['a', 'b', 'c']) }

  it 'is a value: equal domains are one hash key' do
    expect({ domain.restrict(Logic::IncludeOperator, 'a') => true }).to have_key(domain.with(must_include: Set['a']))
    expect(domain.restrict(Logic::IncludeOperator, 'a')).not_to eq(domain.restrict(Logic::ExcludeOperator, 'a'))
  end

  it 'is contradictory when an option must be both selected and not selected' do
    expect(domain).not_to be_empty
    expect(domain.restrict(Logic::IncludeOperator, 'a')).not_to be_empty
    expect(domain.restrict(Logic::IncludeOperator, 'a').restrict(Logic::IncludeOperator, 'b')).not_to be_empty
    expect(domain.restrict(Logic::IncludeOperator, 'a').restrict(Logic::ExcludeOperator, 'b')).not_to be_empty
    expect(domain.restrict(Logic::IncludeOperator, 'a').restrict(Logic::ExcludeOperator, 'a')).to be_empty
    expect(domain.restrict(Logic::ExcludeOperator, 'a').restrict(Logic::ExcludeOperator, 'a')).not_to be_empty
  end

  it 'is contradictory when every option is excluded' do
    expect(domain.restrict(Logic::ExcludeOperator, 'a').restrict(Logic::ExcludeOperator, 'b')).not_to be_empty
    expect(domain.restrict(Logic::ExcludeOperator, 'a').restrict(Logic::ExcludeOperator, 'b').restrict(Logic::ExcludeOperator, 'c')).to be_empty
    expect(described_class.new([]).restrict(Logic::ExcludeOperator, 'a')).not_to be_empty
  end

  it 'stays contradictory whatever comes next' do
    expect(domain.restrict(Logic::IncludeOperator, 'a').restrict(Logic::ExcludeOperator, 'a').restrict(Logic::IncludeOperator, 'b')).to be_empty
  end

  it 'ignores operators that do not apply' do
    expect(domain.restrict(Logic::Eq, 'a').restrict(Logic::NotEq, 'a')).not_to be_empty
  end

  describe '#regions' do
    include_examples 'domain regions', [[Logic::IncludeOperator, 'a'], [Logic::ExcludeOperator, 'b'], [Logic::IncludeOperator, 'b']]

    it 'combines the mentioned options' do
      expect(domain.regions([[Logic::IncludeOperator, 'a'], [Logic::ExcludeOperator, 'b']])).to contain_exactly(
        domain.with(must_include: Set['a', 'b']),
        domain.with(must_include: Set['a'], must_exclude: Set['b']),
        domain.with(must_include: Set['b'], must_exclude: Set['a']),
        domain.with(must_exclude: Set['a', 'b'])
      )
      expect(domain.regions([])).to eq([domain])
    end

    it 'leaves out the selection of nothing when every option is mentioned' do
      expect(described_class.new(['a', 'b']).regions([[Logic::IncludeOperator, 'a'], [Logic::IncludeOperator, 'b']]).size).to eq(3)
    end

    it 'respects prior requirements' do
      regions = domain.restrict(Logic::IncludeOperator, 'a').regions([[Logic::IncludeOperator, 'a'], [Logic::IncludeOperator, 'b']])

      expect(regions.size).to eq(2)
      expect(regions).to all(satisfy { it.must_include.include?('a') })
    end
  end

  describe '#union' do
    let(:with_a_with_b) { domain.restrict(Logic::IncludeOperator, 'a').restrict(Logic::IncludeOperator, 'b') }
    let(:with_a_without_b) { domain.restrict(Logic::IncludeOperator, 'a').restrict(Logic::ExcludeOperator, 'b') }
    let(:without_a_with_b) { domain.restrict(Logic::ExcludeOperator, 'a').restrict(Logic::IncludeOperator, 'b') }

    it 'frees the single option the two differ on' do
      expect(with_a_with_b.union(with_a_without_b)).to eq(domain.restrict(Logic::IncludeOperator, 'a'))
    end

    it 'cannot merge when more than one option differs' do
      expect(with_a_with_b.union(domain)).to be_nil
      expect(with_a_without_b.union(without_a_with_b)).to be_nil
    end
  end

  describe '#to_s' do
    let(:tdc) { build(:type_de_champ_multiple_drop_down_list, drop_down_options: ['a', 'b']) }

    it do
      expect(domain.to_s(tdc)).to eq('toute sélection')
      expect(domain.restrict(Logic::IncludeOperator, 'a').restrict(Logic::ExcludeOperator, 'b').to_s(tdc)).to eq('avec a, sans b')
      expect(domain.restrict(Logic::ExcludeOperator, 'b').to_s(tdc)).to eq('sans b')
    end
  end
end
