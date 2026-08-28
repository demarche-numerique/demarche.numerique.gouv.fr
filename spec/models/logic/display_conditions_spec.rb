# frozen_string_literal: true

describe Logic::DisplayConditions do
  include Logic

  let(:number) { build(:type_de_champ_integer_number, stable_id: 1) }
  let(:hidden) { build(:type_de_champ_drop_down_list, stable_id: 4, drop_down_options: ['x', 'y'], condition: greater_than(n, constant(10))) }
  let(:deeper) { build(:type_de_champ_yes_no, stable_id: 5, condition: ds_eq(h, constant('x'))) }
  let(:type_de_champs) { [number, hidden, deeper] }

  let(:n) { champ_value(1) }
  let(:h) { champ_value(4) }
  let(:d) { champ_value(5) }

  subject(:display_conditions) { described_class.new(type_de_champs) }

  def apply(condition) = display_conditions.apply(condition, display_conditions.conditional_sources(condition))

  it 'joins each comparison with the display condition of its champ' do
    expect(apply(ds_and([ds_eq(h, constant('x')), less_than(n, constant(5))])))
      .to eq(ds_and([ds_and([ds_eq(h, constant('x')), greater_than(n, constant(10))]), less_than(n, constant(5))]))
  end

  it 'lifts a display condition shared by every branch above the or' do
    expect(apply(ds_or([ds_eq(h, constant('x')), ds_eq(h, constant('y'))])))
      .to eq(ds_and([ds_or([ds_eq(h, constant('x')), ds_eq(h, constant('y'))]), greater_than(n, constant(10))]))
  end

  it 'follows the display conditions transitively' do
    expect(apply(ds_eq(d, constant(true))))
      .to eq(ds_and([ds_eq(d, constant(true)), ds_and([ds_eq(h, constant('x')), greater_than(n, constant(10))])]))
  end

  it 'leaves a champ out of its own display condition' do
    hidden.condition = ds_eq(d, constant(true))

    expect(apply(ds_eq(d, constant(true))))
      .to eq(ds_and([ds_eq(d, constant(true)), ds_and([ds_eq(h, constant('x')), ds_eq(d, constant(true))])]))
  end
end
