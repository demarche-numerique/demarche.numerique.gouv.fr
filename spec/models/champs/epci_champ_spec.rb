# frozen_string_literal: true

describe Champs::EpciChamp, type: :model do
  let(:types_de_champ_public) { [{ type: :epci }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_public_champs.first.tap { _1.code_departement = code_departement } }
  let(:code_departement) { nil }

  describe 'validations' do
    subject { champ.validate(:champ_value) }

    describe 'code_departement' do
      context 'when nil' do
        let(:code_departement) { nil }

        it { is_expected.to be_truthy }
      end

      context 'when empty' do
        let(:code_departement) { '' }

        it { is_expected.to be_falsey }
      end

      context 'when included in the departement codes' do
        let(:code_departement) { "01" }

        it { is_expected.to be_truthy }
      end

      context 'when not included in the departement codes' do
        let(:code_departement) { "totoro" }

        it { is_expected.to be_falsey }
      end
    end

    describe 'external_id' do
      before do
        champ.code_departement = code_departement
        champ.external_id = nil
        champ.save!(validate: false)
        champ.update_columns(external_id: external_id)
      end

      context 'when code_departement is nil' do
        let(:code_departement) { nil }
        let(:external_id) { nil }

        it { is_expected.to be_truthy }
      end

      context 'when code_departement is not nil and valid' do
        let(:code_departement) { "01" }

        context 'when external_id is nil' do
          let(:external_id) { nil }

          it { is_expected.to be_truthy }
        end

        context 'when external_id is empty' do
          let(:external_id) { '' }

          it { is_expected.to be_falsey }
        end

        context 'when external_id is included in the epci codes of the departement' do
          let(:external_id) { '200042935' }

          it { is_expected.to be_truthy }
        end

        context 'when external_id is not included in the epci codes of the departement' do
          let(:external_id) { 'totoro' }

          it { is_expected.to be_falsey }
        end
      end
    end

    describe 'value' do
      before do
        champ.value = nil
        champ.code_departement = code_departement
        champ.external_id = nil
        champ.save!(validate: false)
        champ.update_columns(external_id:, value:)
      end

      context 'when code_departement is nil' do
        let(:code_departement) { nil }
        let(:external_id) { nil }
        let(:value) { nil }

        it { is_expected.to be_truthy }
      end

      context 'when external_id is nil' do
        let(:code_departement) { '01' }
        let(:external_id) { nil }
        let(:value) { nil }

        it { is_expected.to be_truthy }
      end

      context 'when code_departement and external_id are not nil and valid' do
        let(:code_departement) { '01' }
        let(:external_id) { '200042935' }

        context 'when value is nil' do
          let(:value) { nil }

          it { is_expected.to be_truthy }
        end

        context 'when value is in departement epci names' do
          let(:value) { 'CA Haut-Bugey Agglomération' }

          it { is_expected.to be_truthy }
        end

        context 'when value is in departement epci names' do
          let(:value) { 'CA Haut-Bugey Agglomération' }

          it { is_expected.to be_truthy }
        end

        context 'when epci name had been renamed' do
          let(:value) { 'totoro' }

          it 'is valid and updates its own value' do
            expect(subject).to be_truthy
            expect(champ.value).to eq('CA Haut-Bugey Agglomération')
          end
        end

        context 'when value is not in departement epci names nor in departement epci codes' do
          let(:value) { 'totoro' }

          it 'is invalid' do
            allow(APIGeoService).to receive(:epcis).with(champ.code_departement).and_return([])
            expect(subject).to be_falsey
          end
        end
      end
    end
  end

  describe 'value' do
    let(:epci) { APIGeoService.epcis('01').first }

    it 'with departement and code' do
      allow(champ).to receive(:type_de_champ).and_return(TypesDeChamp::TypeDeChampBase.build(build(:type_de_champ_epci)))
      champ.code_departement = '01'
      champ.value = epci[:code]
      expect(champ.blank?).to be_falsey
      expect(champ.external_id).to eq(epci[:code])
      expect(champ.value).to eq(epci[:name])
      expect(champ.selected).to eq(epci[:code])
      expect(champ.code).to eq(epci[:code])
      expect(champ.departement?).to be_truthy
      expect(champ.to_s).to eq(epci[:name])
    end
  end

  describe 'double-write of canonical value_json keys' do
    it 'mirrors code_departement to department_code' do
      champ.code_departement = '01'
      expect(champ.value_json['code_departement']).to eq('01')
      expect(champ.value_json['department_code']).to eq('01')
    end

    it 'mirrors code_region to region_code' do
      champ.code_region = '84'
      expect(champ.value_json['code_region']).to eq('84')
      expect(champ.value_json['region_code']).to eq('84')
    end
  end
end
