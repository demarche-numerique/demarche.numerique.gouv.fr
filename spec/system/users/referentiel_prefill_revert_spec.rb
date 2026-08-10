# frozen_string_literal: true

describe 'Referentiel prefill revert', js: true do
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :published, :for_individual, :with_service, types_de_champ_public: [{ type: :text, libelle: 'Nom entreprise' }]) }
  let(:dossier) { create(:dossier, :brouillon, user:, procedure:) }
  let(:champ) { dossier.root_public_champs.first }

  before { login_as user, scope: :user }

  scenario 'usager voit le bouton revert quand la valeur prefilled est modifiee' do
    champ.update!(prefilled: true, value: 'modified by user', prefilled_original_value: { 'value' => 'ACME Corp' })

    visit brouillon_dossier_path(dossier)

    expect(page).to have_button('Remplir à nouveau automatiquement')
  end

  scenario 'usager ne voit pas le bouton si la valeur est intacte' do
    champ.update!(prefilled: true, value: 'ACME Corp', prefilled_original_value: { 'value' => 'ACME Corp' })

    visit brouillon_dossier_path(dossier)

    expect(page).not_to have_button('Remplir à nouveau automatiquement')
  end

  scenario 'usager clique sur le bouton revert et la valeur est restauree' do
    champ.update!(prefilled: true, value: 'modified by user', prefilled_original_value: { 'value' => 'ACME Corp' })

    visit brouillon_dossier_path(dossier)

    expect(page).to have_field('Nom entreprise', with: 'modified by user')
    click_button 'Remplir à nouveau automatiquement'

    expect(page).to have_field('Nom entreprise', with: 'ACME Corp')
    expect(page).not_to have_button('Remplir à nouveau automatiquement')
  end
end
