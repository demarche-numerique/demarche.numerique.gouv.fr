# frozen_string_literal: true

describe Champs::RegionChamp, type: :model do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :regions }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first.tap { _1.update(value:, external_id:) } }
  let(:value) { nil }
  let(:external_id) { nil }

  describe 'validations' do
    subject { champ.validate(:champs_public_value) }

    describe 'external link' do
      context 'when nil' do
        let(:external_id) { nil }

        it { is_expected.to be_truthy }
      end

      context 'when blank' do
        let(:external_id) { '' }

        it { is_expected.to be_falsey }
      end

      context 'when included in the region codes' do
        let(:external_id) { "01" }

        it { is_expected.to be_truthy }
      end

      context 'when not included in the region codes' do
        let(:external_id) { "totoro" }

        it { is_expected.to be_falsey }
      end
    end

    describe 'value' do
      context 'when nil' do
        let(:value) { nil }

        it { is_expected.to be_truthy }
      end

      # not real use case, the value= method override value when blank? aka "" to nil
      context 'when blank' do
        let(:value) { '' }

        xit { is_expected.to be_falsey }
      end

      context 'when included in the region names' do
        let(:value) { "Guyane" }

        it { is_expected.to be_truthy }
      end

      context 'when not included in the region names' do
        let(:value) { "totoro" }

        it { is_expected.to be_falsey }
      end
    end
  end

  describe 'value' do
    it 'with code' do
      champ.value = '01'
      expect(champ.external_id).to eq('01')
      expect(champ.value).to eq('Guadeloupe')
      expect(champ.selected).to eq('01')
      expect(champ.to_s).to eq('Guadeloupe')
    end

    it 'with nil' do
      champ.write_attribute(:value, 'Guadeloupe')
      champ.write_attribute(:external_id, '01')
      champ.value = nil
      expect(champ.external_id).to be_nil
      expect(champ.value).to be_nil
      expect(champ.selected).to be_nil
      expect(champ.to_s).to eq('')
    end

    it 'with blank' do
      champ.write_attribute(:value, 'Guadeloupe')
      champ.write_attribute(:external_id, '01')
      champ.value = ''
      expect(champ.external_id).to be_nil
      expect(champ.value).to be_nil
      expect(champ.selected).to be_nil
      expect(champ.to_s).to eq('')
    end

    it 'with initial nil' do
      champ.write_attribute(:value, nil)
      expect(champ.external_id).to be_nil
      expect(champ.value).to be_nil
      expect(champ.selected).to be_nil
      expect(champ.to_s).to eq('')
    end

    it 'with initial name' do
      champ.write_attribute(:value, 'Guadeloupe')
      expect(champ.external_id).to be_nil
      expect(champ.value).to eq('Guadeloupe')
      expect(champ.selected).to eq('01')
      expect(champ.to_s).to eq('Guadeloupe')
    end

    it 'with Etranger code' do
      champ.value = '99'
      expect(champ.external_id).to eq('99')
      expect(champ.value).to eq('Etranger')
      expect(champ.selected).to eq('99')
      expect(champ.to_s).to eq('Etranger')
    end
  end

  describe 'double-write of canonical value_json keys' do
    it 'persists region_code in value_json after save' do
      champ.value = '01'
      champ.save

      expect(champ.value_json['region_code']).to eq('01')
    end
  end
end
