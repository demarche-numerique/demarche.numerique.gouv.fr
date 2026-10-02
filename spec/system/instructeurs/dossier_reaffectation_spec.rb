# frozen_string_literal: true

describe 'Reassign a dossier to another groupe instructeur', js: true do
  before_all { seed "cases/routage" }

  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.routee }
  let(:groupe) { procedure.defaut_groupe_instructeur }
  let(:autre_groupe) { procedure.groupe_instructeurs.find_by!(label: 'deuxième groupe') }
  let!(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, groupe_instructeur: groupe) }

  before do
    groupe.instructeurs << instructeur
    login_as instructeur.user, scope: :user
  end

  scenario 'the instructeur picks the target group and confirms' do
    visit reaffectation_instructeur_dossier_path(procedure, dossier)

    expect(page).to have_content("Réaffecter le dossier n° #{dossier.id} à un autre groupe instructeur")
    expect(page).to have_button('Réaffecter le dossier à ce groupe', disabled: true)

    select_react_option('deuxième groupe', from: 'Nouveau groupe instructeur')

    expect(page).to have_button('Réaffecter le dossier à ce groupe', disabled: false)

    accept_confirm { click_on 'Réaffecter le dossier à ce groupe' }

    expect(page).to have_content("Le dossier n° #{dossier.id} a été réaffecté au groupe d’instructeurs « deuxième groupe ».")
    expect(dossier.reload.groupe_instructeur).to eq(autre_groupe)
  end
end
