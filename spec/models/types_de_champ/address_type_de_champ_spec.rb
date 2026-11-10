# frozen_string_literal: true

describe TypesDeChamp::AddressTypeDeChamp do
  describe '#columns' do
    let(:procedure) { create(:procedure, public_type_de_champs: [libelle: 'addr', type: 'address']) }
    let(:address_tdc) { procedure.active_revision.type_de_champs.first }
    let(:columns) { address_tdc.columns(procedure_id: procedure.id) }

    it '' do
      expected_columns = [
        "addr",
        "addr – Code postal (5 chiffres)",
        "addr – Commune",
        "addr – Département",
        "addr – Région",
      ]

      expect(columns.map(&:label)).to match_array(expected_columns)
    end

    describe 'main value column' do
      let(:main_column) { columns.find { _1.label == 'addr' } }
      let(:champ) do
        Champs::AddressChamp.new(
          type_de_champ: address_tdc,
          value: '2 rue des Démarches',
          value_json: {
            'label' => '2 rue des Démarches grenoble (38100)',
            'city_code' => '38100',
            'street_address' => '2 rue des Démarches',
            'country_code' => 'FR',
          }
        )
      end

      it 'returns the canonical address label, like the PDF and the UI (not the raw value)' do
        expect(main_column.value(champ)).to eq('2 rue des Démarches grenoble (38100)')
      end
    end

    it 'resolves the legacy region_name column id to $.region_code' do
      h_id = { procedure_id: procedure.id, column_id: "type_de_champ/#{address_tdc.stable_id}-$.region_name" }

      expect(procedure.find_column(h_id:).jsonpath).to eq('$.region_code')
    end

    context 'pickers expose only the new region column' do
      it 'form_filterable_columns has a single Région entry pointing at $.region_code' do
        region_columns = procedure.form_filterable_columns.filter { _1.label == 'addr – Région' }

        expect(region_columns.size).to eq(1)
        expect(region_columns.first).to be_a(Columns::JSONPathColumn)
        expect(region_columns.first.jsonpath).to eq('$.region_code')
      end

      it 'displayable columns expose a single Région entry pointing at $.region_code' do
        region_columns = procedure.columns.filter(&:displayable).filter { _1.label == 'addr – Région' }

        expect(region_columns.size).to eq(1)
        expect(region_columns.first.jsonpath).to eq('$.region_code')
      end
    end
  end
end
