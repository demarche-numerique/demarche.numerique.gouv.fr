# frozen_string_literal: true

describe TypesDeChamp::CommuneTypeDeChamp do
  let(:tdc_commune) { create(:type_de_champ_communes, libelle: 'Ma commune') }
  it { expect(tdc_commune.libelles_for_export).to match_array([['Ma commune', :value], ['Ma commune (Code INSEE)', :code], ['Ma commune (Département)', :departement]]) }

  describe '#columns' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :communes, libelle: 'Ma commune' }]) }
    let(:tdc) { procedure.active_revision.type_de_champs.first }
    let(:jsonpath_columns) { tdc.columns(procedure_id: procedure.id).grep(Columns::JSONPathColumn) }

    it 'exposes the addressable columns as displayable and filterable' do
      addressable = jsonpath_columns.filter(&:displayable)
      expect(addressable.map(&:jsonpath)).to contain_exactly('$.postal_code', '$.city_code', '$.city_name', '$.department_code', '$.region_code')
      expect(addressable).to all(have_attributes(filterable: true))
    end

    it 'exposes the INSEE code, not the postal code, in the Code INSEE column' do
      dossier = create(:dossier, procedure:)
      champ = dossier.champs.first
      champ.update!(code: '10420-10370')

      insee_column = jsonpath_columns.find { it.jsonpath == '$.city_code' }
      expect(insee_column.label).to eq('Ma commune – Code INSEE')
      expect(insee_column.value(champ.reload)).to eq('10420')
    end
  end
end
