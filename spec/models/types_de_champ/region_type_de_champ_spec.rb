# frozen_string_literal: true

describe TypesDeChamp::RegionTypeDeChamp do
  describe '#columns' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :regions, libelle: 'Ma région' }]) }
    let(:tdc) { procedure.active_revision.types_de_champ.first }
    let(:jsonpath_columns) { tdc.columns.grep(Columns::JSONPathColumn) }

    it 'exposes only the region_code addressable column' do
      expect(jsonpath_columns.map(&:jsonpath)).to contain_exactly('$.region_code')
    end
  end
end
