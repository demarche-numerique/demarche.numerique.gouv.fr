# frozen_string_literal: true

describe TypesDeChamp::Epci do
  describe '#columns' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :epci, libelle: 'Mon EPCI' }]) }
    let(:tdc) { procedure.active_revision.type_de_champs.first }
    let(:jsonpath_columns) { tdc.columns(procedure_id: procedure.id).grep(Columns::JSONPathColumn) }

    it 'exposes only department_code and region_code addressable columns' do
      expect(jsonpath_columns.map(&:jsonpath)).to contain_exactly('$.department_code', '$.region_code')
    end
  end
end
