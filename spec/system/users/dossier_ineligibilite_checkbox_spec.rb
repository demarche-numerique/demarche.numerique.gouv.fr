# frozen_string_literal: true

describe 'Dossier Inéligibilité sur une case à cocher', js: true do
  include Logic

  let(:user) { create(:user) }
  let(:procedure) do
    create(:procedure, :published, :for_individual,
      public_type_de_champs: [{ type: :checkbox, libelle: 'certifie', stable_id: 1 }])
  end
  let(:dossier) { create(:dossier, procedure:, user:) }

  before do
    procedure.published_revision.update!(
      ineligibilite_enabled: true,
      ineligibilite_message: 'sry vous ne pouvez pas soumettre',
      ineligibilite_rules: ds_eq(champ_value(1), constant(false))
    )
    login_as user, scope: :user
  end

  scenario "n'alerte pas à l'arrivée, alerte une fois la case décochée" do
    visit brouillon_dossier_path(dossier)
    expect(page).to have_selector('label', text: 'certifie')
    expect(page).to have_no_selector('#modal-eligibilite-rules-dialog', visible: true)
    expect(page).to have_selector(:button, text: "Déposer le dossier", disabled: true)

    find('label', text: 'certifie').click # coche
    wait_for_autosave
    expect(page).to have_no_selector('#modal-eligibilite-rules-dialog', visible: true)
    expect(page).to have_selector(:button, text: "Déposer le dossier", disabled: false)

    find('label', text: 'certifie').click # décoche
    wait_for_autosave
    expect(page).to have_selector('#modal-eligibilite-rules-dialog', visible: true)
    expect(page).to have_content('sry vous ne pouvez pas soumettre')
    expect(page).to have_selector(:button, text: "Déposer le dossier", disabled: true)
  end

  scenario "laisse ouvrir l'explication à la demande, et garde le dépôt bloqué" do
    visit brouillon_dossier_path(dossier)
    expect(page).to have_no_selector('#modal-eligibilite-rules-dialog', visible: true)

    click_on "Pourquoi je ne peux pas déposer mon dossier ?"
    expect(page).to have_selector('#modal-eligibilite-rules-dialog', visible: true)

    expect(dossier.reload.can_passer_en_construction?).to be false
  end
end
