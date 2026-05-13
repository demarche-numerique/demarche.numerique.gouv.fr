# frozen_string_literal: true

describe TypesDeChamp::DropDownListTypeDeChamp do
  describe '#columns' do
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :drop_down_list, referentiel:, drop_down_mode: }] }
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:dropdown_list_tdc) { procedure.active_revision.types_de_champ.first }
    subject { dropdown_list_tdc.columns(procedure_id: procedure.id) }

    context 'when drop_down_mode is advanced (referentiel)' do
      let(:drop_down_mode) { 'advanced' }

      it 'includes value column and referentiel columns' do
        labels = subject.map(&:label)
        expect(labels).to include(dropdown_list_tdc.libelle)
        expect(labels).to include("#{dropdown_list_tdc.libelle} – Référentiel calorie (kcal)")
        expect(labels).to include("#{dropdown_list_tdc.libelle} – Référentiel poids (g)")
      end

      it 'returns a ChampColumn for value followed by JSONPathColumns for referentiel' do
        expect(subject.first).to be_a(Columns::ChampColumn)
        expect(subject.drop(1)).to all(be_a(Columns::JSONPathColumn))
      end

      context 'when an item has nil for a specific header' do
        before do
          item = dropdown_list_tdc.referentiel.items.first
          data = item.data
          data['row']['calorie_kcal'] = nil
          item.update(data:)
        end

        let(:calorie_column) { subject.find { _1.label =~ /calorie/ } }

        it { expect(calorie_column.options_for_select).to eq([["100", "100"], ["170", "170"]]) }
      end
    end

    context 'when drop_down_mode is simple' do
      let(:drop_down_mode) { 'simple' }
      let(:referentiel) { nil }

      it 'returns only the value column' do
        expect(subject.size).to eq(1)
        expect(subject.first).to be_a(Columns::ChampColumn)
        expect(subject.first.label).to eq(dropdown_list_tdc.libelle)
      end
    end

    context 'other true and referentiel off' do
      let(:types_de_champ_public) { [{ type: :drop_down_list, drop_down_options: ['1', '2'], drop_down_other: true }] }
      let(:column) { dropdown_list_tdc.columns(procedure:).first }
      let(:column_value) { Logic::ColumnValue.new(column) }

      it 'exposes other as a choice in the enum' do
        option_labels = column.options_for_select.map(&:first)

        expect(option_labels).to eq(['1', '2', 'Entrer une autre option'])
      end

      describe 'when a champ has a other value' do
        let(:dossier) { create(:dossier, procedure:) }
        let(:champ) { dossier.project_champs.first }

        it 'matches other' do
          champ.value = '__other__'
          champ.value_other = 'something'

          expect(champ.value).to eq('something')
          expect(column.value(champ)).to eq('something')
          expect(column_value.compute([champ])).to eq('__other__')
        end
      end
    end
  end
end
