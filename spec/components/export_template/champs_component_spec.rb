# frozen_string_literal: true

describe ExportTemplate::ChampsComponent, type: :component do
  let(:groupe_instructeur) { create(:groupe_instructeur, procedure:) }
  let(:export_template) { build(:export_template, kind: 'csv', groupe_instructeur:) }
  let(:procedure) { create(:procedure_with_dossiers, :published, types_de_champ_public:, for_individual:) }
  let(:for_individual) { true }
  let(:component) { described_class.new("Champs publics", export_template, procedure.aggregated_revision.public_types_de_champ) }

  describe 'with a flat form' do
    let(:types_de_champ_public) do
      [
        { type: :text, libelle: "Ca va ?", mandatory: true, stable_id: 1 },
        { type: :communes, libelle: "Commune", mandatory: true, stable_id: 17 },
        { type: :siret, libelle: 'Siret', stable_id: 20 },
        { type: :repetition, mandatory: true, stable_id: 7, libelle: "Amis", children: [{ type: 'text', libelle: 'Prénom', stable_id: 8 }] },
      ]
    end

    before { render_inline(component).to_html }

    it 'renders champs within fieldset' do
      expect(page).to have_unchecked_field "Ca va ?"
      expect(page).to have_unchecked_field "Commune"
      expect(page).to have_unchecked_field "Siret"
      expect(page).to have_unchecked_field "(Bloc répétable Amis) – Prénom"
    end
  end

  describe 'with sections spanning several revisions' do
    let(:types_de_champ_public) do
      [
        { type: :text, libelle: 'Avant les sections', stable_id: 30 },
        { type: :header_section, level: 1, libelle: 'Section A', stable_id: 40 },
        { type: :text, libelle: 'Champ supprimé', stable_id: 41 },
        { type: :header_section, level: 2, libelle: 'Sous-section', stable_id: 42 },
        { type: :text, libelle: 'Champ imbriqué', stable_id: 43 },
      ]
    end

    before do
      procedure.draft_revision.remove_type_de_champ(41)
      procedure.publish_revision!(procedure.administrateurs.first)
      render_inline(component).to_html
    end

    it 'groups champs under their top-level section, removed champs included' do
      expect(page.all('.fr-fieldset__element.fr-text--bold').map(&:text)).to eq(['Section A'])

      expect(page).to have_unchecked_field 'Avant les sections'
      expect(page).to have_unchecked_field 'Champ imbriqué'
      expect(page).to have_unchecked_field 'Champ supprimé'
    end
  end
end
