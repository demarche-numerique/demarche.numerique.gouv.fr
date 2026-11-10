# frozen_string_literal: true

describe ExportTemplate::ChampsComponent, type: :component do
  let(:groupe_instructeur) { create(:groupe_instructeur, procedure:) }
  let(:export_template) { build(:export_template, kind: 'csv', groupe_instructeur:) }
  let(:procedure) { create(:procedure_with_dossiers, :published, public_type_de_champs:, for_individual:) }
  let(:for_individual) { true }
  let(:public_type_de_champs) do
    [
      { type: :text, libelle: "Ca va ?", mandatory: true, stable_id: 1 },
      { type: :communes, libelle: "Commune", mandatory: true, stable_id: 17 },
      { type: :siret, libelle: 'Siret', stable_id: 20 },
      { type: :repetition, mandatory: true, stable_id: 7, libelle: "Amis", children: [{ type: 'text', libelle: 'Prénom', stable_id: 8 }] },
    ]
  end
  let(:component) { described_class.new("Champs publics", export_template, procedure.all_revisions_type_de_champs(parent: nil, with_header_section: true)) }
  before { render_inline(component).to_html }

  it 'renders champs within fieldset' do
    procedure
    expect(page).to have_unchecked_field "Ca va ?"
    expect(page).to have_unchecked_field "Commune"
    expect(page).to have_unchecked_field "Siret"
    expect(page).to have_unchecked_field "(Bloc répétable Amis) – Prénom"
  end

  context 'when the template exports a raw column' do
    let(:column) { procedure.find_column(label: 'Commune – Département') }
    let(:export_template) { build(:export_template, kind: 'csv', groupe_instructeur:, exported_columns: [ExportedColumn.new(column:, libelle: 'Département', raw: true)]) }

    it 'keeps the flag in the value posted by its checkbox' do
      expect(JSON.parse(page.find_field('Département', exact: true, checked: true)[:value])).to include('raw' => true)
    end
  end
end
