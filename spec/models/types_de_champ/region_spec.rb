# frozen_string_literal: true

describe TypesDeChamp::Region do
  describe '#columns' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :regions, libelle: 'Ma région' }]) }
    let(:tdc) { procedure.active_revision.type_de_champs.first }
    let(:jsonpath_columns) { tdc.columns(procedure_id: procedure.id).grep(Columns::JSONPathColumn) }

    it 'exposes only the region_code addressable column' do
      expect(jsonpath_columns.map(&:jsonpath)).to contain_exactly('$.region_code')
    end
  end
end
