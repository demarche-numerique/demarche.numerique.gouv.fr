# frozen_string_literal: true

describe Logic::Domain::Enum do
  let(:domain) { described_class.new(['a', 'b', 'c']) }

  it 'is a value: equal domains are one hash key' do
    expect({ domain => true }).to have_key(described_class.new(['c', 'b', 'a']))
    expect(domain).not_to eq(described_class.new(['a', 'b']))
  end

  it 'is empty without options' do
    expect(domain).not_to be_empty
    expect(described_class.new([])).to be_empty
  end

  it 'narrows with equality' do
    expect(domain.restrict(Logic::Eq, 'a')).not_to be_empty
    expect(domain.restrict(Logic::Eq, 'a').restrict(Logic::Eq, 'a')).not_to be_empty
    expect(domain.restrict(Logic::Eq, 'a').restrict(Logic::Eq, 'b')).to be_empty
    expect(domain.restrict(Logic::Eq, 'unknown')).to be_empty
  end

  it 'narrows with inequality' do
    expect(domain.restrict(Logic::Eq, 'a').restrict(Logic::NotEq, 'a')).to be_empty
    expect(domain.restrict(Logic::Eq, 'a').restrict(Logic::NotEq, 'b')).not_to be_empty
    expect(domain.restrict(Logic::NotEq, 'a').restrict(Logic::NotEq, 'b')).not_to be_empty
    expect(domain.restrict(Logic::NotEq, 'a').restrict(Logic::NotEq, 'b').restrict(Logic::NotEq, 'c')).to be_empty
  end

  it 'ignores operators that do not apply' do
    expect(domain.restrict(Logic::IncludeOperator, 'a')).not_to be_empty
  end

  it 'models booleans' do
    boolean = described_class.new([true, false])

    expect(boolean.restrict(Logic::Eq, true)).not_to be_empty
    expect(boolean.restrict(Logic::Eq, true).restrict(Logic::Eq, false)).to be_empty
    expect(boolean.restrict(Logic::NotEq, true).restrict(Logic::Eq, false)).not_to be_empty
  end

  describe '#regions' do
    include_examples 'domain regions', [[Logic::Eq, 'a'], [Logic::NotEq, 'b']]

    it 'isolates the mentioned options' do
      expect(domain.regions([[Logic::Eq, 'a'], [Logic::NotEq, 'b']])).to eq([described_class.new(['a']), described_class.new(['b']), described_class.new(['c'])])
      expect(domain.regions([[Logic::Eq, 'a']])).to eq([described_class.new(['a']), described_class.new(['b', 'c'])])
      expect(domain.regions([[Logic::Eq, 'unknown']])).to eq([domain])
      expect(domain.regions([])).to eq([domain])
    end
  end

  describe '#union' do
    it 'joins the options and refuses other kinds' do
      expect(domain.restrict(Logic::Eq, 'a').union(domain.restrict(Logic::Eq, 'c'))).to eq(described_class.new(['a', 'c']))
      expect(domain.union(Logic::Domain::Blank)).to be_nil
    end
  end

  describe '#to_s' do
    let(:tdc) { build(:type_de_champ_drop_down_list, drop_down_options: ['a', 'b', 'c']) }

    it 'lists the options in the champ order' do
      expect(described_class.new(['c', 'a']).to_s(tdc)).to eq('a, c')
      expect(described_class.new(['unknown']).to_s(tdc)).to eq('unknown')
    end

    it 'names the other option' do
      expect(described_class.new([Champs::DropDownListChamp::OTHER]).to_s(tdc)).to eq('Autre')
    end

    it 'names booleans' do
      expect(described_class.new([true]).to_s(build(:type_de_champ_yes_no))).to eq('Oui')
      expect(described_class.new([false, true]).to_s(build(:type_de_champ_yes_no))).to eq('Non, Oui')
    end
  end
end
