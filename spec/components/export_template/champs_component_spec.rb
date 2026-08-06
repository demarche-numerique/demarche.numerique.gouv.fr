# frozen_string_literal: true

describe ExportTemplate::ChampsComponent, type: :component do
  let(:groupe_instructeur) { create(:groupe_instructeur, procedure:) }
  let(:export_template) { build(:export_template, kind: 'csv', groupe_instructeur:) }
  let(:procedure) { create(:procedure_with_dossiers, :published, types_de_champ_public:, for_individual:) }
  let(:for_individual) { true }
  let(:types_de_champ_public) do
    [
      { type: :text, libelle: "Ca va ?", mandatory: true, stable_id: 1 },
      { type: :communes, libelle: "Commune", mandatory: true, stable_id: 17 },
      { type: :siret, libelle: 'Siret', stable_id: 20 },
      { type: :repetition, mandatory: true, stable_id: 7, libelle: "Amis", children: [{ type: 'text', libelle: 'Prénom', stable_id: 8 }] },
    ]
  end
  let(:component) { described_class.new("Champs publics", export_template, procedure.aggregated_root_types_de_champ_public.reject(&:explication?)) }
  before { render_inline(component).to_html }

  it 'renders champs within fieldset' do
    procedure
    expect(page).to have_unchecked_field "Ca va ?"
    expect(page).to have_unchecked_field "Commune"
    expect(page).to have_unchecked_field "Siret"
    expect(page).to have_unchecked_field "(Bloc répétable Amis) – Prénom"
  end
end
