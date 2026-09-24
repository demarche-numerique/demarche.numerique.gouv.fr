# frozen_string_literal: true

describe Instructeurs::ClearFilterButtonsComponent, type: :component do
  let(:component) { described_class.new(filters:, procedure_presentation:, statut:) }
  let(:instructeur) { create(:instructeur) }
  let(:assign_to) { create(:assign_to, procedure:, instructeur:) }
  let(:procedure_presentation) { create(:procedure_presentation, assign_to: assign_to) }
  let(:statut) { 'tous' }
  let(:filters) { [filter] }

  def to_filter((label, filter)) = FilteredColumn.new(column: procedure.find_column(label: label), filter: filter)

  before { render_inline(component) }

  describe "visible text" do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]) }
    let(:first_type_de_champ) { procedure.active_revision.public_root_type_de_champs.first }
    let(:filter) { to_filter([first_type_de_champ.libelle, { operator: 'match', value: ['true'] }]) }

    context 'when type_de_champ text' do
      it 'should passthrough value' do
        expect(page).to have_text("true")
      end
    end

    context 'when type_de_champ yes_no' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :yes_no }]) }

      it 'should transform value' do
        expect(page).to have_text("oui")
      end
    end

    context 'when filter is state' do
      let(:filter) { to_filter(['État du dossier', { operator: 'match', value: ['en_construction'] }]) }

      it 'should get i18n value' do
        expect(page).to have_text("En construction")
      end
    end

    context 'when filter is a date' do
      let(:filter) { to_filter(['Date de création', { operator: 'match', value: ['15/06/2023'] }]) }

      it 'should get formatted value' do
        expect(page).to have_text("15 juin 2023")
      end
    end

    context 'when filter is a date range' do
      let(:filter) { to_filter(['Date de création', { operator: 'between', value: ['2023-06-15', '2023-06-30'] }]) }

      it 'renders a single tag with both dates, removing the whole range' do
        expect(page).to have_button(count: 1)
        expect(page).to have_text("Date de création : du 15 juin 2023 au 30 juin 2023")
        expect(page).to have_field('filter[filter][operator]', with: 'match', type: 'hidden')
      end

      context 'with only a start date' do
        let(:filter) { to_filter(['Date de création', { operator: 'between', value: ['2023-06-15', ''] }]) }

        it { expect(page).to have_text("Date de création : à partir du 15 juin 2023") }
      end

      context 'with only an end date' do
        let(:filter) { to_filter(['Date de création', { operator: 'between', value: ['', '2023-06-30'] }]) }

        it { expect(page).to have_text("Date de création : jusqu’au 30 juin 2023") }
      end
    end

    context 'when there are multiple filters' do
      let(:filters) do
        [
          to_filter(['État du dossier', { operator: 'match', value: ['en_construction', 'en_instruction'] }]),
          to_filter(['Date de création', { operator: 'match', value: ['15/06/2023'] }]),
        ]
      end

      it 'should display all filters' do
        text = "État du dossier : En constructionÉtat du dossier : En instructionDate de création : 15 juin 2023"
        expect(page).to have_text(text)
      end
    end
  end

  describe "hidden inputs" do
    let(:procedure) { create(:procedure) }

    context 'with 2 filters' do
      let(:en_construction_filter) { to_filter(['État du dossier', { operator: 'match', value: ['en_construction'] }]) }
      let(:en_instruction_filter) { to_filter(['État du dossier', { operator: 'match', value: ['en_instruction'] }]) }
      let(:column_id) { procedure.find_column(label: 'État du dossier').id }
      let(:filters) { [en_construction_filter, en_instruction_filter] }

      it 'should have the necessary inputs' do
        expect(page).to have_field('statut', with: 'tous', type: 'hidden')

        expect(page.all('form').count).to eq(2)

        del_en_construction = page.all('form').first

        expect(del_en_construction).to have_text('En construction')
        expect(del_en_construction).to have_field('filter[id]', with: column_id, type: 'hidden')
        expect(del_en_construction).to have_field('filter[filter][operator]', with: 'match', type: 'hidden')

        del_en_instruction = page.all('form').last

        expect(del_en_instruction).to have_text('En instruction')
        expect(del_en_instruction).to have_field('filter[id]', with: column_id, type: 'hidden')
        expect(del_en_instruction).to have_field('filter[filter][operator]', with: 'match', type: 'hidden')
      end
    end
  end
end
