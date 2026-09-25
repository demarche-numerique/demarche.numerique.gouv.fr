# frozen_string_literal: true

describe Champs::CommuneChamp do
  let(:public_type_de_champs) { [{ type: :communes }] }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_champs_public.first }

  let(:code_insee) { '63102' }
  let(:postal_code) { '63290' }
  let(:department_code) { '63' }
  let(:region_code) { '84' }
  let(:city_name) { 'Châteldon' }

  describe 'value' do
    context 'default' do
      before do
        champ.postal_code = postal_code
        champ.external_id = code_insee
        champ.save
      end

      it 'find commune' do
        expect(champ.to_s).to eq('Châteldon (63290)')
        expect(champ.name).to eq('Châteldon')
        expect(champ.external_id).to eq(code_insee)
        expect(champ.code).to eq(code_insee)
        expect(champ.department_code).to eq(department_code)
        expect(champ.postal_code).to eq(postal_code)
        expect(champ.type_de_champ.champ_value_for_export(champ, :value)).to eq 'Châteldon (63290)'
        expect(champ.type_de_champ.champ_value_for_export(champ, :code)).to eq '63102'
        expect(champ.type_de_champ.champ_value_for_export(champ, :departement)).to eq '63 – Puy-de-Dôme'
      end
    end

    context 'with tricky bug (should not happen, but it happens)' do
      before do
        champ.external_id = ''
        champ.value = 'Gagny'
        champ.save
      end

      it 'fails' do
        expect(champ).to receive(:instrument_external_id_error)
        expect(champ.validate(:champ_value)).to be_falsey
        expect(champ.errors).to include('external_id')
      end
    end

    context 'with code' do
      before do
        champ.code = '63102-63290'
        champ.save
      end

      it 'find commune' do
        expect(champ.to_s).to eq('Châteldon (63290)')
        expect(champ.name).to eq('Châteldon')
        expect(champ.external_id).to eq(code_insee)
        expect(champ.code).to eq(code_insee)
        expect(champ.department_code).to eq(department_code)
        expect(champ.postal_code).to eq(postal_code)
        expect(champ.type_de_champ.champ_value_for_export(champ, :value)).to eq 'Châteldon (63290)'
        expect(champ.type_de_champ.champ_value_for_export(champ, :code)).to eq '63102'
        expect(champ.type_de_champ.champ_value_for_export(champ, :departement)).to eq '63 – Puy-de-Dôme'
      end
    end
  end

  describe 'canonical value_json keys' do
    context 'when commune is set via code=' do
      before do
        champ.code = '63102-63290'
        champ.save
      end

      it 'persists only the canonical keys in value_json' do
        expect(champ.value_json['postal_code']).to eq('63290')
        expect(champ.value_json['department_code']).to eq('63')
        expect(champ.value_json['region_code']).to eq('84')
        expect(champ.value_json['city_name']).to eq('Châteldon')
        expect(champ.value_json['city_code']).to eq('63102')
        expect(champ.value_json.keys).not_to include('code_postal', 'code_departement', 'code_region')
      end
    end
  end
end
