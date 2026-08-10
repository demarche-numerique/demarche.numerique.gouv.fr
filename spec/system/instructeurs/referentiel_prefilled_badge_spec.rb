# frozen_string_literal: true

describe 'Referentiel prefilled badge', js: true do
  let(:user) { create(:user) }
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, :for_individual, :with_service, types_de_champ_public: [{ type: :text, libelle: 'Nom entreprise' }]) }
  let(:dossier) { create(:dossier, :en_construction, user:, procedure:) }
  let(:champ) { dossier.root_public_champs.first }

  before do
    procedure.defaut_groupe_instructeur.add(instructeur)
    login_as instructeur.user, scope: :user
  end

  scenario 'instructeur voit icone verifiee si valeur intacte' do
    champ.update!(prefilled: true, value: 'ACME Corp', prefilled_original_value: { 'value' => 'ACME Corp' })

    visit instructeur_dossier_path(procedure, dossier)

    expect(page).to have_css('.fr-icon-checkbox-circle-line')
  end

  scenario 'instructeur voit warning si valeur changee' do
    champ.update!(prefilled: true, value: 'Modified Corp', prefilled_original_value: { 'value' => 'ACME Corp' })

    visit instructeur_dossier_path(procedure, dossier)

    expect(page).to have_text("Donnée du référentiel modifiée par l’usager")
  end

  scenario 'pas de badge si pas prefilled' do
    champ.update!(value: 'Something')

    visit instructeur_dossier_path(procedure, dossier)

    expect(page).not_to have_css('.fr-icon-checkbox-circle-line')
    expect(page).not_to have_text("Donnée du référentiel modifiée par l'usager")
  end
end
