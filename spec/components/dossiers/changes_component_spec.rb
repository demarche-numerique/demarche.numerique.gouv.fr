# frozen_string_literal: true

RSpec.describe Dossiers::ChangesComponent, type: :component do
  subject { render_inline(described_class.new(changed_columns:)) }

  let(:changed_columns) { [changed_column] }

  def build_column(label:, type:, options_for_select: [])
    Column.new(procedure_id: 1, table: 'type_de_champ', column: 'preview', label:, type:, options_for_select:)
  end

  def build_changed_column(label:, type:, value:, previous_value: nil, options_for_select: [])
    ChangedColumn.new(build_column(label:, type:, options_for_select:), value, previous_value)
  end

  context 'when there are no changes' do
    let(:changed_columns) { [] }

    it 'does not render' do
      expect(subject.to_html).to be_empty
    end
  end

  context 'with a simple text value' do
    let(:changed_column) { build_changed_column(label: 'Adresse', type: :text, value: '47 Rue Le Peletier 75009 Paris') }

    it 'renders the label and the new value in bold' do
      expect(subject).to have_content('Adresse')
      expect(subject).to have_selector('strong', text: '47 Rue Le Peletier 75009 Paris')
    end
  end

  context 'with a nil value' do
    let(:changed_column) { build_changed_column(label: 'Adresse', type: :text, value: nil, previous_value: 'Ancienne adresse') }

    it 'says the value was removed' do
      expect(subject).to have_content('La valeur a été supprimée')
    end
  end

  context 'with a boolean value' do
    let(:changed_column) { build_changed_column(label: 'Accord', type: :boolean, value: true) }

    it 'renders a human readable value' do
      expect(subject).to have_selector('strong', text: 'Oui')
    end
  end

  context 'with a false boolean value' do
    let(:changed_column) { build_changed_column(label: 'Accord', type: :boolean, value: false, previous_value: true) }

    it 'renders "Non" rather than a removal' do
      expect(subject).to have_selector('strong', text: 'Non')
      expect(subject).not_to have_content('La valeur a été supprimée')
    end
  end

  context 'with a datetime value' do
    let(:changed_column) { build_changed_column(label: 'Rendez-vous', type: :datetime, value: Time.zone.local(2026, 6, 16, 14, 30)) }

    it 'renders a formatted date and time' do
      expect(subject).to have_selector('strong', text: I18n.l(Time.zone.local(2026, 6, 16, 14, 30), format: :short_with_time))
    end
  end

  context 'with number values' do
    let(:changed_columns) do
      [
        build_changed_column(label: 'Entier', type: :integer, value: 42),
        build_changed_column(label: 'Décimal', type: :decimal, value: 3.14),
      ]
    end

    it 'renders the numbers' do
      expect(subject).to have_selector('strong', text: '42')
      expect(subject).to have_selector('strong', text: '3.14')
    end
  end

  context 'with a date value' do
    let(:changed_column) { build_changed_column(label: 'Date', type: :date, value: Date.new(2026, 6, 16)) }

    it 'renders a formatted date' do
      expect(subject).to have_selector('strong', text: I18n.l(Date.new(2026, 6, 16), format: :short))
    end
  end

  context 'with an enum value' do
    let(:changed_column) do
      build_changed_column(label: 'Région', type: :enum, value: 'bfc', options_for_select: [['Bourgogne-Franche-Comté', 'bfc']])
    end

    it 'renders the human readable label' do
      expect(subject).to have_selector('strong', text: 'Bourgogne-Franche-Comté')
    end
  end

  context 'with a geojson value' do
    let(:changed_column) do
      build_changed_column(label: 'Carte', type: :geojson, value: { type: 'FeatureCollection' }, previous_value: { type: 'FeatureCollection' })
    end

    it 'says the area has been changed' do
      expect(subject).to have_content('La zone géographique a été modifiée')
    end
  end

  context 'with enums values' do
    let(:changed_column) do
      build_changed_column(label: 'Choix', type: :enums, value: ['Musique', 'Danse'], previous_value: ['Musique', 'Théâtre'])
    end

    it 'shows added and removed values' do
      expect(subject).to have_content('Ajouté :')
      expect(subject).to have_selector('strong', text: 'Danse')
      expect(subject).to have_content('Retiré :')
      expect(subject).to have_selector('strong', text: 'Théâtre')
    end

    it 'does not list unchanged values' do
      expect(subject).not_to have_selector('strong', text: 'Musique')
    end

    context 'when only the order changed' do
      let(:changed_column) do
        build_changed_column(label: 'Choix', type: :enums, value: ['Danse', 'Musique'], previous_value: ['Musique', 'Danse'])
      end

      it 'says the value has been changed' do
        expect(subject).to have_content('La valeur a été modifiée')
        expect(subject).not_to have_content('Ajouté :')
      end
    end
  end

  context 'with attachments values' do
    def attachment(filename)
      Struct.new(:blob).new(Struct.new(:filename).new(filename))
    end

    let(:changed_column) do
      build_changed_column(
        label: 'Pièces',
        type: :attachments,
        value: [attachment('Contrat.pdf'), attachment('Annexe.pdf')],
        previous_value: [attachment('Contrat.pdf'), attachment('Ancien.pdf')]
      )
    end

    it 'shows added and removed file names' do
      expect(subject).to have_content('Ajouté :')
      expect(subject).to have_selector('strong', text: 'Annexe.pdf')
      expect(subject).to have_content('Retiré :')
      expect(subject).to have_selector('strong', text: 'Ancien.pdf')
    end

    it 'does not list unchanged file names' do
      expect(subject).not_to have_selector('strong', text: 'Contrat.pdf')
    end
  end
end
