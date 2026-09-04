# frozen_string_literal: true

describe Champs::DepartementChamp, type: :model do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :departements }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_champs_public.first.tap { _1.update_columns(value:, external_id:) } }
  let(:value) { nil }
  let(:external_id) { nil }

  describe 'validations' do
    subject { champ.validate(:champ_value) }

    describe 'external link' do
      context 'when nil' do
        let(:external_id) { nil }

        it { is_expected.to be_truthy }
      end

      context 'when blank' do
        let(:external_id) { '' }

        it { is_expected.to be_falsey }
      end

      context 'when included in the departement codes' do
        let(:external_id) { "01" }

        it { is_expected.to be_truthy }
      end

      context 'when not included in the departement codes' do
        let(:external_id) { "totoro" }

        it 'reports an inclusion error on external_id' do
          is_expected.to be_falsey
          expect(champ.errors).to be_of_kind(:external_id, :inclusion)
          expect(champ.errors.messages_for(:external_id)).to eq(["doit être un code de département valide"])
        end
      end
    end

    describe 'value' do
      context 'when nil' do
        let(:value) { nil }

        it { is_expected.to be_truthy }
      end

      context 'when blank' do
        let(:value) { '' }

        it { is_expected.to be_falsey }
      end

      context 'when included in the departement names' do
        let(:value) { "Ain" }

        it { is_expected.to be_truthy }
      end

      context 'when not included in the departement names' do
        let(:value) { "totoro" }

        it 'reports an inclusion error on value' do
          is_expected.to be_falsey
          expect(champ.errors).to be_of_kind(:value, :inclusion)
          expect(champ.errors.messages_for(:value)).to eq(["doit être un nom de département valide"])
        end
      end
    end
  end

  describe 'value' do
    it 'with code having 2 chars' do
      champ.value = '01'
      expect(champ.external_id).to eq('01')
      expect(champ.code).to eq('01')
      expect(champ.name).to eq('Ain')
      expect(champ.value).to eq('Ain')
      expect(champ.selected).to eq('01')
      expect(champ.to_s).to eq('01 – Ain')
    end

    it 'with code having 3 chars' do
      champ.value = '971'
      expect(champ.external_id).to eq('971')
      expect(champ.code).to eq('971')
      expect(champ.name).to eq('Guadeloupe')
      expect(champ.value).to eq('Guadeloupe')
      expect(champ.selected).to eq('971')
      expect(champ.to_s).to eq('971 – Guadeloupe')
    end

    it 'with alphanumeric code' do
      champ.value = '2B'
      expect(champ.external_id).to eq('2B')
      expect(champ.code).to eq('2B')
      expect(champ.name).to eq('Haute-Corse')
      expect(champ.value).to eq('Haute-Corse')
      expect(champ.selected).to eq('2B')
      expect(champ.to_s).to eq('2B – Haute-Corse')
    end

    it 'with a name as short as a code' do
      champ.value = 'Var'
      expect(champ).to have_attributes(external_id: '83', value: 'Var')
    end

    it 'with a name as short as a code, once saved' do
      champ.value = '83'
      expect(champ.value).to eq('Var')
      champ.save!
      expect(champ.reload).to have_attributes(external_id: '83', value: 'Var')
    end

    it 'with nil' do
      champ.write_attribute(:value, 'Ain')
      champ.write_attribute(:external_id, '01')
      champ.value = nil
      expect(champ.external_id).to be_nil
      expect(champ.code).to be_nil
      expect(champ.name).to be_nil
      expect(champ.value).to be_nil
      expect(champ.selected).to be_nil
      expect(champ.to_s).to eq('')
    end

    it 'with blank' do
      champ.write_attribute(:value, 'Ain')
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
      expect(champ.code).to be_nil
      expect(champ.name).to be_nil
      expect(champ.value).to be_nil
      expect(champ.selected).to be_nil
      expect(champ.to_s).to eq('')
    end

    it 'with initial code and name' do
      champ.write_attribute(:value, '01 - Ain')
      expect(champ.external_id).to be_nil
      expect(champ.code).to eq('01')
      expect(champ.name).to eq('Ain')
      expect(champ.value).to eq('01 - Ain')
      expect(champ.selected).to eq('01')
      expect(champ.to_s).to eq('01 – Ain')
    end

    it 'with initial code and alphanumeric name' do
      champ.write_attribute(:value, '2B - Haute-Corse')
      expect(champ.external_id).to be_nil
      expect(champ.code).to eq('2B')
      expect(champ.name).to eq('Haute-Corse')
      expect(champ.value).to eq('2B - Haute-Corse')
      expect(champ.selected).to eq('2B')
      expect(champ.to_s).to eq('2B – Haute-Corse')
    end
  end

  describe 'double-write of canonical value_json keys' do
    it 'persists department_code and region_code alongside code_region after save' do
      champ.value = '01'
      champ.save

      expect(champ.value_json['code_region']).to eq('84')
      expect(champ.value_json['region_code']).to eq('84')
      expect(champ.value_json['department_code']).to eq('01')
    end
  end
end
