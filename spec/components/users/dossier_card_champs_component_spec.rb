# frozen_string_literal: true

RSpec.describe Users::DossierCardChampsComponent, type: :component do
  let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Titre' }]) }
  let(:dossier) { create(:dossier, :en_construction, procedure:, populate_champs: true) }
  let(:column) { procedure.customizable_columns.first }

  it 'renders the formatted value with an info icon when the champ has a value' do
    champ = dossier.champs.find { _1.stable_id == column.stable_id }
    champ.update(value: 'Presse Océan')

    render_inline(described_class.new(columns: [column], champs_by_stable_id: { column.stable_id => champ.reload }))

    expect(page).to have_css('.fr-icon-info-i')
    expect(page).to have_text('Presse Océan')
  end

  it 'renders the formatted value for a brouillon dossier' do
    brouillon = create(:dossier, :brouillon, procedure:, populate_champs: true)
    champ = brouillon.champs.find { _1.stable_id == column.stable_id }
    champ.update(value: 'Valeur brouillon')

    render_inline(described_class.new(columns: [column], champs_by_stable_id: { column.stable_id => champ.reload }))

    expect(page).to have_css('.fr-icon-info-i')
    expect(page).to have_text('Valeur brouillon')
  end

  it 'renders nothing when the champ is missing or empty' do
    render_inline(described_class.new(columns: [column], champs_by_stable_id: {}))

    expect(page).not_to have_css('.fr-icon-info-i')
  end

  context 'with a dossier link champ' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié' }]) }

    it 'labels the line with the bare libelle' do
      champ = dossier.champs.find { _1.stable_id == column.stable_id }
      champ.update(value: '42')

      render_inline(described_class.new(columns: [column], champs_by_stable_id: { column.stable_id => champ.reload }))

      expect(page).to have_text('Dossier lié')
      expect(page).not_to have_text('N° dossier')
      expect(page).to have_text('42')
    end

    it 'labels the line with the bare libelle from a saved and reloaded customisation' do
      champ = dossier.champs.find { _1.stable_id == column.stable_id }
      champ.update(value: '42')
      personnalisation = create(:dossiers_list_personnalisation, procedure:, displayed_columns: [column])
      Current.reset

      columns = DossiersListPersonnalisation.find(personnalisation.id).displayed_columns
      render_inline(described_class.new(columns:, champs_by_stable_id: { column.stable_id => champ.reload }))

      expect(page).to have_text('Dossier lié')
      expect(page).not_to have_text('N° dossier')
      expect(page).to have_text('42')
    end

    it 'labels the line with the bare libelle once the field is removed from a later revision' do
      champ = dossier.champs.find { _1.stable_id == column.stable_id }
      champ.update(value: '42')
      personnalisation = create(:dossiers_list_personnalisation, procedure:, displayed_columns: [column])
      procedure.draft_revision.remove_type_de_champ(column.stable_id)
      procedure.publish_revision!(procedure.administrateurs.first)
      Current.reset

      columns = DossiersListPersonnalisation.find(personnalisation.id).displayed_columns
      render_inline(described_class.new(columns:, champs_by_stable_id: { column.stable_id => champ.reload }))

      expect(page).to have_text('Dossier lié')
      expect(page).not_to have_text('N° dossier')
      expect(page).to have_text('42')
    end
  end
end
