# frozen_string_literal: true

describe TypesDeChamp::Address do
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

    context 'legacy region_name column (kept for backward compat)' do
      let(:legacy_column) { columns.find { _1.is_a?(Columns::JSONPathColumn) && _1.jsonpath == '$.region_name' } }

      it 'is not displayable nor filterable' do
        expect(legacy_column).to be_present
        expect(legacy_column.displayable).to be(false)
        expect(legacy_column.filterable).to be(false)
      end

      it 'is resolvable by procedure.find_column with its h_id' do
        expect(procedure.find_column(h_id: legacy_column.h_id)).to eq(legacy_column)
      end

      it 'survives a ColumnType serialization round-trip' do
        serialized = ColumnType.new.serialize(legacy_column)
        deserialized = ColumnType.new.deserialize(serialized)

        expect(deserialized).to eq(legacy_column)
      end
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
