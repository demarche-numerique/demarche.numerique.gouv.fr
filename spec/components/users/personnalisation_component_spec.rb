# frozen_string_literal: true

RSpec.describe Users::PersonnalisationComponent, type: :component do
  let(:procedure) do
    create(:procedure, :published, public_type_de_champs: [
      { type: :header_section, libelle: 'Identité' },
      { type: :text, libelle: 'Nom', mandatory: true },
    ])
  end
  let(:personnalisation) { build(:dossiers_list_personnalisation, procedure:) }

  it 'renders the procedure title and a react MultipleSelect scoped to the procedure' do
    render_inline(described_class.new(procedure:, personnalisation:))

    expect(page).to have_text(procedure.libelle)
    expect(page).to have_css('.fr-card')
    react = page.find('react-component')
    expect(react['name']).to eq('Select/MultipleSelect')
    props = JSON.parse(react['props'])
    expect(props['name']).to eq("personnalisations[#{procedure.id}][displayed_columns][]")
    expect(props['emptyHint']).to eq('Affichage non personnalisé pour les dossiers de cette démarche.')
    expect(props['sections'].first['label']).to eq('1. Identité')
    expect(props['sections'].first['items'].first).to include('label' => 'Nom', 'mandatory' => true)
  end

  context 'when the form has no section' do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :text, libelle: 'Nom', mandatory: true },
      ])
    end

    it 'renders a flat list without any separator' do
      render_inline(described_class.new(procedure:, personnalisation:))

      props = JSON.parse(page.find('react-component')['props'])
      expect(props).not_to have_key('sections')
      expect(props['items'].first).to include('label' => 'Nom', 'mandatory' => true)
    end
  end

  context 'with a saved and reloaded dossier link customisation' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié' }]) }
    let(:column) { procedure.customizable_columns.first }
    let(:personnalisation) do
      saved = create(:dossiers_list_personnalisation, procedure:, displayed_columns: [column])
      Current.reset
      DossiersListPersonnalisation.find(saved.id)
    end

    it 'offers and selects the field under its bare libelle' do
      render_inline(described_class.new(procedure:, personnalisation:))

      props = JSON.parse(page.find('react-component')['props'])
      expect(props['items']).to contain_exactly(include('label' => 'Dossier lié', 'value' => column.id))
      expect(props['value']).to eq([column.id])
    end
  end
end
