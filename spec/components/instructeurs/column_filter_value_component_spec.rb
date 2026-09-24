# frozen_string_literal: true

describe Instructeurs::ColumnFilterValueComponent, type: :component do
  let!(:instructeur_procedure) { create(:instructeurs_procedure, display_message_notifications: 'none') }

  before do
    component = nil

    ActionView::Base.empty.form_with(url: "/") do |form|
      component = described_class.new(filtered_column:, form:, instructeur_procedure:)
    end

    render_inline(component)
  end

  let(:filtered_column) { FilteredColumn.new(column:, filter:) }
  let(:filter) { { operator: 'match', value: ['value'] } }

  describe 'the select case' do
    let!(:column) do
      column = double("Column", column: :value, type: :enum, tdc_type: "drop_down_list", options_for_select:, mandatory: true, h_id: {}, label: 'option1 option2')
      allow(column).to receive(:is_a?).with(Columns::ChampColumn).and_return(true)
      column
    end
    let(:options_for_select) { ['option1', 'option2'] }

    let(:react_component) { page.find('react-component') }
    let(:react_props_items) { JSON.parse(react_component['props']) }

    it {
      expect(react_props_items["items"]).to eq([
        "option1", "option2",
      ])
    }
  end

  describe 'the input case' do
    let(:column) { double("Column", column: :value, type: :datetime, mandatory: true, h_id: {}, label: 'date') }

    it { expect(page).to have_selector('input[name="filter[filter][value][]"][type="date"]', count: 1) }
  end

  describe 'the date range case' do
    let(:column) { double("Column", column: :value, type: :datetime, mandatory: true, h_id: {}, label: 'date') }
    let(:filter) { { operator: 'between', value: ['2025-02-12', '2025-02-15'] } }

    it 'renders a start and an end date, filled with the current range' do
      expect(page).to have_select('Opérateur', selected: 'Période')
      expect(page).to have_field('Du', type: 'date', with: '2025-02-12')
      expect(page).to have_field('Au', type: 'date', with: '2025-02-15')
      expect(page).to have_button('Mettre à jour', count: 1)
    end
  end

  describe 'the yes no case' do
    let(:column) { double("Column", column: :value, type: :boolean, tdc_type: "yes_no", options_for_select: Champs::YesNoChamp.options, mandatory:, h_id: {}, label: 'oui non') }

    context 'when the column is mandatory' do
      let(:mandatory) { true }
      it do
        expect(page).to have_selector('input[name="filter[filter][value][]"][type="radio"]', count: 2)
        expect(page).to have_selector('label[for="value_-filter-operator-match-value-value-_true"]', text: 'oui')
        expect(page).to have_selector('label[for="value_-filter-operator-match-value-value-_false"]', text: 'non')
      end
    end

    context 'when the column is not mandatory' do
      let(:mandatory) { false }

      it do
        expect(page).to have_selector('input[name="filter[filter][value][]"][type="radio"]', count: 3)
        expect(page).to have_selector('label[for="value_-filter-operator-match-value-value-_true"]', text: 'oui')
        expect(page).to have_selector('label[for="value_-filter-operator-match-value-value-_false"]', text: 'non')
        expect(page).to have_selector('label[for="value_-filter-operator-match-value-value-_nil"]', text: 'Non renseigné')
      end
    end
  end

  describe 'the checkbox case' do
    let(:column) { double("Column", column: :value, type: :boolean, tdc_type: "checkbox", options_for_select: Champs::CheckboxChamp.options, mandatory:, label: 'coché non coché', h_id: {}) }

    context 'when the column is mandatory' do
      let(:mandatory) { true }

      it do
        expect(page).to have_selector('input[name="filter[filter][value][]"][type="radio"]', count: 2)
        expect(page).to have_selector('label[for="value_-filter-operator-match-value-value-_true"]', text: 'coché')
        expect(page).to have_selector('label[for="value_-filter-operator-match-value-value-_false"]', text: 'non coché')
      end
    end

    context 'when the column is not mandatory' do
      let(:mandatory) { false }

      it do
        expect(page).to have_selector('input[name="filter[filter][value][]"][type="radio"]', count: 2)
        expect(page).to have_selector('label[for="value_-filter-operator-match-value-value-_true"]', text: 'coché')
        expect(page).to have_selector('label[for="value_-filter-operator-match-value-value-_false"]', text: 'non coché')
      end
    end
  end

  describe 'the notification_type case' do
    let(:column) { double("Column", column: 'notification_type', type: :enum, options_for_select:, h_id: {}, label: 'notifications sur le dossier') }
    let(:options_for_select) { I18n.t('instructeurs.dossiers.filterable_notification').map(&:to_a).map(&:reverse) }

    context 'when the instructeur has chosen not to have certain notifications' do
      let(:react_component) { page.find('react-component') }
      let(:react_props_items) { JSON.parse(react_component['props']) }

      it {
        expect(react_props_items["items"].map(&:first)).to eq([
          "Déposé depuis longtemps", "Expire bientôt", "Bientôt supprimé", "Dossier modifié", "Annotation privée", "Avis externe", "En attente de correction", "En attente de réponse", "En attente d’avis externe",
        ])
      }
    end
  end

  describe 'label truncation' do
    let(:long_label) { 'a' * 60 }
    let(:column) do
      double(
        "Column",
        column: :value,
        type: :string,
        mandatory: true,
        h_id: {},
        label: long_label
      )
    end

    it 'renders a truncated visible label and a sr-only full label' do
      expect(page).to have_selector(
        'span[aria-hidden="true"][title]',
        text: long_label.truncate(50)
      )
      expect(page.find('span[aria-hidden="true"]')[:title]).to eq(long_label)
      expect(page).to have_selector(
        'span.fr-sr-only',
        text: long_label
      )
    end
  end

  describe 'short label' do
    let(:column) do
      double(
        "Column",
        column: :value,
        type: :string,
        mandatory: true,
        h_id: {},
        label: 'label court'
      )
    end

    it 'renders only one visible span without sr-only or title' do
      expect(page).to have_selector('span', text: 'label court')

      expect(page).not_to have_selector('span.fr-sr-only')
      expect(page).not_to have_selector('span[aria-hidden]')
      expect(page).not_to have_selector('span[title]')
    end
  end
end
