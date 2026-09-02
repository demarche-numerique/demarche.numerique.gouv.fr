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
end
