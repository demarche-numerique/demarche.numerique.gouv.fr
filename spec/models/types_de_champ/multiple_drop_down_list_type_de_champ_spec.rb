# frozen_string_literal: true

describe TypesDeChamp::MultipleDropDownListTypeDeChamp do
  describe '#columns' do
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:procedure) do
      create(:procedure, types_de_champ_public: [{ type: :multiple_drop_down_list, referentiel:, drop_down_mode: 'advanced' }])
    end
    let(:multiple_dropdown_list_tdc) { procedure.active_revision.types_de_champ.first }

    it 'returns a collection of columns in advanced mode' do
      columns = multiple_dropdown_list_tdc.columns(procedure:)

      expect(columns).to be_an(Array)
      expect(columns).to contain_exactly(an_instance_of(Columns::MultipleDropDownColumn))
    end
  end
end
