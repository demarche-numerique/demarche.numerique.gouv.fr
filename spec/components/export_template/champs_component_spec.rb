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

  context 'with deprecated columns' do
    let(:public_type_de_champs) do
      [
        { type: :address, libelle: 'Adresse', stable_id: 30 },
        { type: :communes, libelle: 'Ville', stable_id: 32 },
        { type: :repetition, libelle: 'Amis', stable_id: 7, children: [{ type: :address, libelle: 'Domicile', stable_id: 31 }] },
      ]
    end

    it 'does not render them' do
      expect(page).to have_unchecked_field('Adresse – Région', exact: true, count: 1)
      expect(page).to have_unchecked_field('(Bloc répétable Amis) – Domicile – Région', exact: true, count: 1)
      expect(page).not_to have_field('Ville - département', exact: true)
    end

    context 'when one is already in the export template' do
      let(:deprecated_column) { procedure.find_column(h_id: { procedure_id: procedure.id, column_id: 'type_de_champ/30-$.region_name' }) }
      let(:export_template) { build(:export_template, kind: 'csv', groupe_instructeur:, exported_columns: [ExportedColumn.new(column: deprecated_column, libelle: 'Adresse – Région')]) }

      it 'renders it checked' do
        expect(page).to have_checked_field('Adresse – Région', exact: true, count: 1)
        expect(page).to have_unchecked_field('Adresse – Région', exact: true, count: 1)
      end
    end
  end
end
