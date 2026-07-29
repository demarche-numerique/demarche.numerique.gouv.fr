# frozen_string_literal: true

RSpec.describe ViewableChamp::SectionComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }

  # Instantiation lives here so the refactor only touches this one place.
  let(:component) do
    described_class.new(
      champs: dossier.public_champs,
      demande_seen_at: nil,
      profile: 'instructeur'
    )
  end

  before { render_inline(component) }

  context 'with nested header sections' do
    let(:types_de_champ_public) do
      [
        { type: :header_section, level: 1, libelle: 'Section A' },
        { type: :text,                     libelle: 'Champ A1' },
        { type: :header_section, level: 2, libelle: 'Sous-section A' },
        { type: :text,                     libelle: 'Champ A2' },
        { type: :header_section, level: 1, libelle: 'Section B' },
        { type: :text,                     libelle: 'Champ B1' },
      ]
    end

    it 'renders every header section and every champ label' do
      ['Section A', 'Sous-section A', 'Section B', 'Champ A1', 'Champ A2', 'Champ B1'].each do |label|
        expect(page).to have_text(label)
      end
    end
  end

  context 'with a repetition' do
    let(:types_de_champ_public) do
      [
        { type: :header_section, level: 1, libelle: 'Section' },
        { type: :repetition, libelle: 'Répétition', children: [{ type: :text, libelle: 'Membre' }] },
      ]
    end

    it 'renders the section, the repetition and its member' do
      ['Section', 'Répétition', 'Membre'].each do |label|
        expect(page).to have_text(label)
      end
    end
  end
end
