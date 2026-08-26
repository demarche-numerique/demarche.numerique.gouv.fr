# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillGeo, type: :model do
  let(:procedure) { create(:procedure) }

  describe 'ancestors' do
    let(:type_de_champ) { build(:type_de_champ_pays, procedure: procedure) }
    subject { described_class.build(type_de_champ, procedure.active_revision) }

    it { is_expected.to be_kind_of(TypesDeChamp::Prefill) }
  end

  context 'for a pays type de champ' do
    let(:type_de_champ) { build(:type_de_champ_pays, procedure: procedure) }

    describe '#possible_values' do
      let(:expected_values) { "Un <a href=\"https://en.wikipedia.org/wiki/ISO_3166-2\" target=\"_blank\" rel=\"noopener noreferrer\">code pays ISO 3166-2</a><br><a title=\"Toutes les valeurs possibles — Nouvel onglet\" target=\"_blank\" rel=\"noopener noreferrer\" href=\"/procedures/#{procedure.path}/prefill_type_de_champs/#{type_de_champ.id}\">Voir toutes les valeurs possibles</a>" }
      subject(:possible_values) { described_class.new(type_de_champ, procedure.active_revision).possible_values }

      before { type_de_champ.reload }

      it { expect(possible_values).to match(expected_values) }
    end

    describe '#to_assignable_attributes' do
      let(:champ) { Champs::PaysChamp.new }
      subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

      context 'when the value is a country code' do
        let(:value) { 'FR' }

        it { is_expected.to eq({ value: 'FR' }) }
      end

      context 'when the value is a country name' do
        let(:value) { 'France' }

        it { is_expected.to eq({ value: 'France' }) }
      end

      context 'when the value is an unknown country code' do
        let(:value) { 'ZZ' }

        it { is_expected.to be_nil }
      end

      context 'when the value is not a country' do
        let(:value) { 'value' }

        it { is_expected.to be_nil }
      end

      context 'when the value is an excluded French overseas departement' do
        let(:value) { 'Guadeloupe' }

        it { is_expected.to be_nil }
      end

      context 'when the value is not a String' do
        let(:value) { ['FR'] }

        it { is_expected.to be_nil }
      end
    end
  end

  context 'for a regions type de champ' do
    let(:type_de_champ) { create(:type_de_champ_regions, procedure: procedure) }

    describe '#possible_values' do
      let(:expected_values) { "Un <a href=\"https://fr.wikipedia.org/wiki/R%C3%A9gion_fran%C3%A7aise\" target=\"_blank\" rel=\"noopener noreferrer\">code INSEE de région</a><br><a title=\"Toutes les valeurs possibles — Nouvel onglet\" target=\"_blank\" rel=\"noopener noreferrer\" href=\"/procedures/#{procedure.path}/prefill_type_de_champs/#{type_de_champ.id}\">Voir toutes les valeurs possibles</a>" }
      subject(:possible_values) { described_class.new(type_de_champ, procedure.active_revision).possible_values }

      before { type_de_champ.reload }

      it { expect(possible_values).to eq(expected_values) }
    end

    describe '#to_assignable_attributes' do
      let(:champ) { Champs::RegionChamp.new }
      subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

      context 'when the value is a region code' do
        let(:value) { '53' }

        it { is_expected.to eq({ value: '53' }) }
      end

      context 'when the value is a region name' do
        let(:value) { 'Bretagne' }

        it { is_expected.to eq({ value: 'Bretagne' }) }
      end

      context 'when the value is an unknown region code' do
        let(:value) { '00' }

        it { is_expected.to be_nil }
      end

      context 'when the value is not a region' do
        let(:value) { 'value' }

        it { is_expected.to be_nil }
      end

      context 'when the value is not a String' do
        let(:value) { ['53'] }

        it { is_expected.to be_nil }
      end
    end
  end

  context 'for a departements type de champ' do
    let(:type_de_champ) { build(:type_de_champ_departements, procedure: procedure) }

    describe '#possible_values' do
      let(:expected_values) {
        "Un <a href=\"https://fr.wikipedia.org/wiki/Num%C3%A9rotation_des_d%C3%A9partements_fran%C3%A7ais\" target=\"_blank\">numéro de département</a><br><a title=\"Toutes les valeurs possibles — Nouvel onglet\" target=\"_blank\" rel=\"noopener noreferrer\" href=\"/procedures/#{procedure.path}/prefill_type_de_champs/#{type_de_champ.id}\">Voir toutes les valeurs possibles</a>"
      }
      subject(:possible_values) { described_class.new(type_de_champ, procedure.active_revision).possible_values }

      before { type_de_champ.reload }

      it { expect(possible_values).to match(expected_values) }
    end

    describe '#to_assignable_attributes' do
      let(:champ) { Champs::DepartementChamp.new }
      subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

      context 'when the value is a departement code' do
        let(:value) { '01' }

        it { is_expected.to eq({ value: '01' }) }
      end

      context 'when the value is a 3-characters departement code' do
        let(:value) { '971' }

        it { is_expected.to eq({ value: '971' }) }
      end

      context 'when the value is a departement name' do
        let(:value) { 'Aisne' }

        it { is_expected.to eq({ value: 'Aisne' }) }
      end

      context 'when the value is an unknown departement code' do
        let(:value) { '00' }

        it { is_expected.to be_nil }
      end

      context 'when the value is not a departement' do
        let(:value) { 'value' }

        it { is_expected.to be_nil }
      end

      context 'when the value is not a String' do
        let(:value) { ['01'] }

        it { is_expected.to be_nil }
      end
    end
  end
end
