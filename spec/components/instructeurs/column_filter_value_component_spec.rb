# frozen_string_literal: true

describe Instructeurs::ColumnFilterValueComponent, type: :component do
  let!(:instructeur_procedure) { create(:instructeurs_procedure, display_message_notifications: 'none') }

  before do
    component = nil

    ActionView::Base.empty.form_with(url: "/") do |form|
      component = described_class.new(filtered_column:, form:, instructeur_procedure:, groupe_instructeur_ids: [])
    end

    allow(component).to receive(:current_instructeur).and_return(instructeur_procedure.instructeur)
    render_inline(component)
  end

  let(:filtered_column) { FilteredColumn.new(column:, filter:) }
  let(:filter) { { operator: 'match', value: ['value'] } }

  describe 'the select case' do
    let!(:column) do
      column = double("Column", column: :value, type: :enum, tdc_type: "drop_down_list", options_for_select:, filter_options: options_for_select.dup, mandatory: true, h_id: {}, label: 'option1 option2')
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

  describe 'the linked procedure title filter' do
    let(:procedure) { create(:procedure, :published, :routee, instructeurs: [instructeur], public_type_de_champs: [{ type: :dossier_link }]) }
    let(:instructeur) { create(:instructeur) }
    let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:) }
    let(:column) do
      tdc = procedure.active_revision.public_root_type_de_champs.first
      tdc.columns(procedure_id: procedure.id).third
    end
    let(:accessible_dossier) { create(:dossier, :en_construction, procedure:, groupe_instructeur: procedure.defaut_groupe_instructeur) }
    let(:other_group_dossier) { create(:dossier, :en_construction, procedure:, groupe_instructeur: procedure.groupe_instructeurs.last) }

    let(:filtered_column) do
      accessible_dossier.champ_data.find_by!(stream: Dossier::MAIN_STREAM).update!(value_json: { 'procedure_title' => 'Démarche accessible' })
      other_group_dossier.champ_data.find_by!(stream: Dossier::MAIN_STREAM).update!(value_json: { 'procedure_title' => 'Démarche autre groupe' })
      super()
    end

    it 'only offers titles from dossiers the instructeur can access' do
      props = JSON.parse(page.find('react-component')['props'])
      expect(props.fetch('items')).to eq([['Démarche accessible', 'Démarche accessible']])
    end
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
    let(:column) { double("Column", column: :value, type: :boolean, tdc_type: "yes_no", options_for_select: Champs::YesNoChamp.options, filter_options: Champs::YesNoChamp.options.dup, mandatory:, h_id: {}, label: 'oui non') }

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
    let(:column) { double("Column", column: :value, type: :boolean, tdc_type: "checkbox", options_for_select: Champs::CheckboxChamp.options, filter_options: Champs::CheckboxChamp.options.dup, mandatory:, label: 'coché non coché', h_id: {}) }

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
    let(:column) { double("Column", column: 'notification_type', type: :enum, options_for_select:, filter_options: options_for_select.dup, h_id: {}, label: 'notifications sur le dossier') }
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

  describe 'the suggestions case' do
    let(:column) { double("Column", column: :value, type: :text, suggestions?: true, filter_options:, mandatory: true, h_id: {}, label: 'Intitulé') }

    context 'with values to suggest' do
      let(:filter_options) { ['Démarche Alpha', 'Démarche Bravo'] }

      it 'offers them in a combobox taking free text' do
        props = JSON.parse(page.find('react-component')['props'])
        expect(props).to include('items' => filter_options, 'allows_custom_value' => true)
      end
    end

    context 'without any value to suggest' do
      let(:filter_options) { [] }

      it 'keeps a plain text input' do
        expect(page).to have_no_css('react-component')
        expect(page).to have_selector('input[name="filter[filter][value][]"][type="text"][maxlength]')
      end
    end
  end

  describe 'label truncation' do
    let(:long_label) { 'a' * 60 }
    let(:column) do
      double(
        "Column",
        column: :value,
        type: :string,
        suggestions?: false,
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
        suggestions?: false,
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
