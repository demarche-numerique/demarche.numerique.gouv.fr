# frozen_string_literal: true

describe Logic::PossibleValues::Enums do
  let(:values) { described_class.new(['a', 'b', 'c']) }

  it 'is a value: equal domains are one hash key' do
    expect({ values.restrict(Logic::IncludeOperator, 'a') => true }).to have_key(values.with(must_include: Set['a']))
    expect(values.restrict(Logic::IncludeOperator, 'a')).not_to eq(values.restrict(Logic::ExcludeOperator, 'a'))
  end

  it 'is contradictory when an option must be both selected and not selected' do
    expect(values).not_to be_empty
    expect(values.restrict(Logic::IncludeOperator, 'a')).not_to be_empty
    expect(values.restrict(Logic::IncludeOperator, 'a').restrict(Logic::IncludeOperator, 'b')).not_to be_empty
    expect(values.restrict(Logic::IncludeOperator, 'a').restrict(Logic::ExcludeOperator, 'b')).not_to be_empty
    expect(values.restrict(Logic::IncludeOperator, 'a').restrict(Logic::ExcludeOperator, 'a')).to be_empty
    expect(values.restrict(Logic::ExcludeOperator, 'a').restrict(Logic::ExcludeOperator, 'a')).not_to be_empty
  end

  it 'is contradictory when every option is excluded' do
    expect(values.restrict(Logic::ExcludeOperator, 'a').restrict(Logic::ExcludeOperator, 'b')).not_to be_empty
    expect(values.restrict(Logic::ExcludeOperator, 'a').restrict(Logic::ExcludeOperator, 'b').restrict(Logic::ExcludeOperator, 'c')).to be_empty
    expect(described_class.new([]).restrict(Logic::ExcludeOperator, 'a')).not_to be_empty
  end

  it 'stays contradictory whatever comes next' do
    expect(values.restrict(Logic::IncludeOperator, 'a').restrict(Logic::ExcludeOperator, 'a').restrict(Logic::IncludeOperator, 'b')).to be_empty
  end

  it 'ignores operators that do not apply' do
    expect(values.restrict(Logic::Eq, 'a').restrict(Logic::NotEq, 'a')).not_to be_empty
  end
end
