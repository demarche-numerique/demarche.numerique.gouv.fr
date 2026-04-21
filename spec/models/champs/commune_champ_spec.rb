# frozen_string_literal: true

describe Champs::CommuneChamp do
  let(:types_de_champ_public) { [{ type: :communes }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

  let(:code_insee) { '63102' }
  let(:code_postal) { '63290' }
  let(:code_departement) { '63' }

  describe 'value' do
    context 'default' do
      before do
        champ.code_postal = code_postal
        champ.external_id = code_insee
        champ.save
      end

      it 'find commune' do
        expect(champ.to_s).to eq('Châteldon (63290)')
        expect(champ.name).to eq('Châteldon')
        expect(champ.external_id).to eq(code_insee)
        expect(champ.code).to eq(code_insee)
        expect(champ.code_departement).to eq(code_departement)
        expect(champ.code_postal).to eq(code_postal)
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
        expect(champ.validate(:champs_public_value)).to be_falsey
        expect(champ.errors).to include('external_id')
      end
    end

    context 'not_in_api_geo? and in_api_geo?' do
      context 'when not_in_api_geo is not set' do
        it do
          expect(champ.not_in_api_geo?).to be false
          expect(champ.in_api_geo?).to be true
        end
      end

      context 'when not_in_api_geo is true' do
        before { champ.not_in_api_geo = 'true' }

        it do
          expect(champ.not_in_api_geo?).to be true
          expect(champ.in_api_geo?).to be false
        end
      end

      context 'when not_in_api_geo is empty string' do
        before { champ.not_in_api_geo = '' }

        it do
          expect(champ.not_in_api_geo?).to be false
          expect(champ.in_api_geo?).to be true
        end
      end
    end

    context 'validation in fallback mode (not_in_api_geo)' do
      before do
        champ.not_in_api_geo = 'true'
        champ.value = 'Ma commune inconnue'
        champ.save!
      end

      it 'is valid without external_id' do
        expect(champ.external_id).to be_nil
        expect(champ.validate(:champs_public_value)).to be true
      end

      context 'when mandatory and value is blank' do
        let(:types_de_champ_public) { [{ type: :communes, mandatory: true }] }

        before do
          champ.value = ''
          champ.save!
        end

        it 'is mandatory_blank' do
          expect(champ.mandatory_blank?).to be true
        end
      end
    end

    context 'name in fallback mode' do
      before do
        champ.not_in_api_geo = 'true'
        champ.value = 'Ma commune inconnue'
        champ.save!
      end

      it 'returns value as name' do
        expect(champ.name).to eq('Ma commune inconnue')
      end
    end

    context 'transition normal to fallback' do
      before do
        champ.code_postal = code_postal
        champ.external_id = code_insee
        champ.save!
      end

      it 'resets structured data when switching to fallback' do
        expect(champ.code_departement).to eq(code_departement)
        expect(champ.external_id).to eq(code_insee)

        champ.not_in_api_geo = 'true'
        champ.value = 'Commune libre'
        champ.save!

        expect(champ.external_id).to be_nil
        expect(champ.code_departement).to be_nil
        expect(champ.code_postal).to be_nil
        expect(champ.code_region).to be_nil
      end
    end

    context 'transition fallback to normal' do
      before do
        champ.not_in_api_geo = 'true'
        champ.value = 'Commune libre'
        champ.save!
      end

      it 'clears the free text value when switching back to normal' do
        expect(champ.value).to eq('Commune libre')

        champ.not_in_api_geo = ''
        champ.save!

        expect(champ.value).to be_nil
      end

      it 'allows setting structured data again' do
        champ.not_in_api_geo = ''
        champ.code_postal = code_postal
        champ.external_id = code_insee
        champ.save!

        expect(champ.in_api_geo?).to be true
        expect(champ.name).to eq('Châteldon')
        expect(champ.code_departement).to eq(code_departement)
      end
    end

    context 'champ_value and export in fallback mode' do
      before do
        champ.not_in_api_geo = 'true'
        champ.value = 'Ma commune inconnue'
        champ.save!
      end

      it 'champ_value returns value directly' do
        expect(champ.type_de_champ.champ_value(champ)).to eq('Ma commune inconnue')
      end

      it 'champ_value_for_export returns free text for :value' do
        expect(champ.type_de_champ.champ_value_for_export(champ, :value)).to eq('Ma commune inconnue')
      end

      it 'champ_value_for_export returns empty string for :code' do
        expect(champ.type_de_champ.champ_value_for_export(champ, :code)).to eq('')
      end

      it 'champ_value_for_export returns empty string for :departement' do
        expect(champ.type_de_champ.champ_value_for_export(champ, :departement)).to eq('')
      end

      it 'champ_value_for_tag returns value directly' do
        expect(champ.type_de_champ.champ_value_for_tag(champ, :value)).to eq('Ma commune inconnue')
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
        expect(champ.code_departement).to eq(code_departement)
        expect(champ.code_postal).to eq(code_postal)
        expect(champ.type_de_champ.champ_value_for_export(champ, :value)).to eq 'Châteldon (63290)'
        expect(champ.type_de_champ.champ_value_for_export(champ, :code)).to eq '63102'
        expect(champ.type_de_champ.champ_value_for_export(champ, :departement)).to eq '63 – Puy-de-Dôme'
      end
    end
  end
end
