# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillCivilite do
  let(:procedure) { build(:procedure) }
  let(:type_de_champ) { build(:type_de_champ_civilite, procedure: procedure) }
  let(:champ) { Champs::CiviliteChamp.new }

  describe 'ancestors' do
    subject { described_class.build(type_de_champ, procedure.active_revision) }

    it { is_expected.to be_kind_of(TypesDeChamp::Prefill) }
  end

  describe '#to_assignable_attributes' do
    subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

    context 'when the value is "M."' do
      let(:value) { 'M.' }

      it { is_expected.to eq({ value: 'M.' }) }
    end

    context 'when the value is "Mme"' do
      let(:value) { 'Mme' }

      it { is_expected.to eq({ value: 'Mme' }) }
    end

    context 'when the value is not a civilite' do
      let(:value) { 'value' }

      it { is_expected.to be_nil }
    end

    {
      'Monsieur' => 'M.', 'M' => 'M.', 'mr' => 'M.',
      'male' => 'M.', 'homme' => 'M.',
      'Madame' => 'Mme', 'mlle' => 'Mme',
      'Mademoiselle' => 'Mme', 'female' => 'Mme', 'femme' => 'Mme',
    }.each do |input, expected|
      context "when the value is #{input.inspect}" do
        let(:value) { input }

        it { is_expected.to eq({ value: expected }) }
      end
    end

    context 'when the value is blank' do
      let(:value) { '' }

      it { is_expected.to be_nil }
    end

    context 'when the value is not a String' do
      let(:value) { 42 }

      it { is_expected.to be_nil }
    end
  end
end
