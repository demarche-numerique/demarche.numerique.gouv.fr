# frozen_string_literal: true

describe TypesDeChamp::CommuneTypeDeChamp do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :communes, libelle: 'Ma commune' }]) }
  let(:tdc) { procedure.active_revision.type_de_champs.first }

  describe '#legacy_export_columns' do
    subject(:columns) { tdc.legacy_export_columns(procedure_id: procedure.id) }

    it 'keeps the historical name cell, and reuses the catalogue code INSEE and département' do
      expect(columns.map(&:first)).to eq(['Ma commune', 'Ma commune (Code INSEE)', 'Ma commune (Département)'])
      expect(columns.map(&:second)).to match([
        an_instance_of(Columns::LegacyColumn),
        an_instance_of(Columns::JSONPathColumn).and(having_attributes(jsonpath: '$.city_code')),
        an_instance_of(Columns::JSONPathColumn).and(having_attributes(jsonpath: '$.department_code')),
      ])
    end
  end

  describe '#columns' do
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

    it 'keeps legacy jsonpaths resolvable but hidden' do
      legacy = jsonpath_columns.reject(&:displayable)
      expect(legacy.map(&:jsonpath)).to contain_exactly('$.code_postal', '$.code_departement')
      expect(legacy).to all(have_attributes(filterable: false))
    end
  end
end
