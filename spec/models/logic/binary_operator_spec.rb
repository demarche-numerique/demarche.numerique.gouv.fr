# frozen_string_literal: true

describe Logic::BinaryOperator do
  include Logic
  let(:two_greater_than_one) { greater_than(constant(2), constant(1)) }

  describe '#type' do
    it { expect(two_greater_than_one.type).to eq(:boolean) }
  end

  describe '#to_s' do
    it { expect(two_greater_than_one.to_s([])).to eq('(2 > 1)') }
  end

  describe '#==' do
    it do
      expect(two_greater_than_one).to eq(greater_than(constant(2), constant(1)))
      expect(two_greater_than_one).not_to eq(greater_than(constant(1), constant(2)))
    end
  end

  describe '#errors' do
    it { expect(greater_than(constant(1), constant(true)).errors).to eq([{ operator_name: "Logic::GreaterThan", type: :required_number }]) }
  end

  describe '#sources' do
    let(:champ) { Champs::IntegerNumberChamp.new(value: nil, stable_id: 1) }
    let(:champ2) { Champs::IntegerNumberChamp.new(value: nil, stable_id: 2) }

    it do
      expect(two_greater_than_one.sources).to eq([])
      expect(greater_than(champ_value(champ.stable_id), constant(2)).sources).to eq([champ.stable_id])
      expect(greater_than(constant(2), champ_value(champ.stable_id)).sources).to eq([champ.stable_id])
      expect(greater_than(champ_value(champ.stable_id), champ_value(champ2.stable_id)).sources).to eq([champ.stable_id, champ2.stable_id])
    end
  end

  describe '#hash' do
    it do
      expect(ds_eq(constant(1), constant(2)).hash).to eq(ds_eq(constant(1), constant(2)).hash)
      expect(ds_eq(constant(1), constant(2)).hash).to eq(ds_eq(constant(2), constant(1)).hash)
      expect(ds_eq(constant(1), constant(2)).hash).not_to eq(ds_not_eq(constant(2), constant(1)).hash)
    end
  end
end

describe Logic::GreaterThan do
  include Logic
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :integer_number }]) }
  let(:tdc) { procedure.active_revision.types_de_champ.first }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { Champs::IntegerNumberChamp.new(value: nil, stable_id: tdc.stable_id, dossier:) }

  it 'computes' do
    expect(greater_than(constant(1), constant(1)).compute).to be(false)
    expect(greater_than(constant(2), constant(1)).compute).to be(true)
    expect(greater_than(champ_value(champ.stable_id), constant(2)).compute([champ])).to be(false)
  end
end

describe Logic::GreaterThanEq do
  include Logic
  it 'computes' do
    expect(greater_than_eq(constant(0), constant(1)).compute).to be(false)
    expect(greater_than_eq(constant(1), constant(1)).compute).to be(true)
    expect(greater_than_eq(constant(2), constant(1)).compute).to be(true)
  end
end

describe Logic::LessThan do
  include Logic
  it 'computes' do
    expect(less_than(constant(1), constant(1)).compute).to be(false)
    expect(less_than(constant(1), constant(2)).compute).to be(true)
  end
end

describe Logic::LessThanEq do
  include Logic
  it 'computes' do
    expect(less_than_eq(constant(0), constant(1)).compute).to be(true)
    expect(less_than_eq(constant(1), constant(1)).compute).to be(true)
    expect(less_than_eq(constant(2), constant(1)).compute).to be(false)
  end
end
