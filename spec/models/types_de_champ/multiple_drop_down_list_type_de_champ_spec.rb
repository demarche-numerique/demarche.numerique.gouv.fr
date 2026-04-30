# frozen_string_literal: true

describe TypesDeChamp::MultipleDropDownListTypeDeChamp do
  describe '#columns' do
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:procedure) do
      create(:procedure, types_de_champ_public: [{ type: :multiple_drop_down_list, referentiel:, drop_down_mode: 'advanced' }])
    end
    let(:multiple_dropdown_list_tdc) { procedure.active_revision.types_de_champ.first }

    it 'returns one column per referentiel header in advanced mode' do
      columns = multiple_dropdown_list_tdc.columns(procedure:)

      expect(columns.size).to eq(3)
      expect(columns).to all(be_an_instance_of(Columns::MultipleDropDownColumn))
      expect(columns.map(&:label)).to eq([
        "#{multiple_dropdown_list_tdc.libelle} – Référentiel option",
        "#{multiple_dropdown_list_tdc.libelle} – Référentiel calorie (kcal)",
        "#{multiple_dropdown_list_tdc.libelle} – Référentiel poids (g)",
      ])
    end
  end

  describe '#libelles_for_export' do
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:procedure) do
      create(:procedure, types_de_champ_public: [{ type: :multiple_drop_down_list, referentiel:, drop_down_mode: 'advanced' }])
    end
    let(:multiple_dropdown_list_tdc) { procedure.active_revision.types_de_champ.first }

    it 'returns a single column with path :value for standard export' do
      libelles = multiple_dropdown_list_tdc.libelles_for_export

      expect(libelles).to eq([[multiple_dropdown_list_tdc.libelle, :value]])
    end
  end

  describe '#champ_value_for_export' do
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:procedure) do
      create(:procedure, types_de_champ_public: [{ type: :multiple_drop_down_list, referentiel:, drop_down_mode: 'advanced' }])
    end
    let(:multiple_dropdown_list_tdc) { procedure.active_revision.types_de_champ.first }
    let(:selected_items) { referentiel.items.first(2) }
    let(:champ) do
      multiple_dropdown_list_tdc.build_champ(value: selected_items.map(&:id).to_json).tap do |c|
        c.referentiels = selected_items.each_with_object({}) do |item, acc|
          acc[item.id.to_s] = { 'data' => item.data.merge('headers' => referentiel.headers) }
        end
      end
    end

    it 'returns user values and not referentiel ids' do
      expect(multiple_dropdown_list_tdc.champ_value_for_export(champ)).to eq('fromage, dessert')
    end

    context 'when the champ is not in advanced mode' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [{ type: :multiple_drop_down_list, drop_down_mode: 'simple' }])
      end
      let(:champ) { multiple_dropdown_list_tdc.build_champ(value: ['val1', 'val2'].to_json) }

      it 'returns selected option labels' do
        expect(multiple_dropdown_list_tdc.champ_value_for_export(champ)).to eq('val1, val2')
      end
    end
  end
end
