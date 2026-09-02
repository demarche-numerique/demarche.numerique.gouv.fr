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
end
