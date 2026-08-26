# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillBoolean do
  let(:procedure) { build(:procedure) }
  let(:type_de_champ) { build(:type_de_champ_yes_no, procedure: procedure) }
  let(:champ) { Champs::YesNoChamp.new }

  describe 'ancestors' do
    subject { described_class.build(type_de_champ, procedure.active_revision) }

    it { is_expected.to be_kind_of(TypesDeChamp::Prefill) }
  end

  describe '.build' do
    it 'is used for yes_no and checkbox types de champ' do
      [build(:type_de_champ_yes_no), build(:type_de_champ_checkbox)].each do |type_de_champ|
        expect(TypesDeChamp::Prefill.build(type_de_champ, procedure.active_revision)).to be_kind_of(described_class)
      end
    end
  end

  describe '#to_assignable_attributes' do
    subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

    context 'when the value is "true"' do
      let(:value) { 'true' }

      it { is_expected.to eq({ value: 'true' }) }
    end

    context 'when the value is "false"' do
      let(:value) { 'false' }

      it { is_expected.to eq({ value: 'false' }) }
    end

    context 'when the value is a boolean' do
      let(:value) { true }

      it { is_expected.to eq({ value: 'true' }) }
    end

    context 'when the value is castable to true' do
      ['1', 'on', 't', 1].each do |castable_value|
        let(:value) { castable_value }

        it { is_expected.to eq({ value: 'true' }) }
      end
    end

    context 'when the value is castable to false' do
      ['0', 'off', 'f', 0].each do |castable_value|
        let(:value) { castable_value }

        it { is_expected.to eq({ value: 'false' }) }
      end
    end

    context 'when the value is an unrecognized string' do
      let(:value) { 'non' }

      it { is_expected.to be_nil }
    end

    context 'when the value is blank' do
      let(:value) { '' }

      it { is_expected.to be_nil }
    end

    context 'when the value is not a scalar' do
      let(:value) { ['true'] }

      it { is_expected.to be_nil }
    end
  end
end
