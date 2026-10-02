# frozen_string_literal: true

describe 'Reassign the dossiers of a groupe instructeur', js: true do
  before_all { seed "cases/routage" }

  let(:administrateur) { administrateurs.default }
  let(:procedure) { procedures.routee }
  let(:groupe) { procedure.defaut_groupe_instructeur }
  let(:autre_groupe) { procedure.groupe_instructeurs.find_by!(label: 'deuxième groupe') }
  let!(:dossiers) { create_list(:dossier, 2, :en_construction, :with_individual, procedure:, groupe_instructeur: groupe) }

  before { login_as administrateur.user, scope: :user }

  scenario 'the administrateur picks the target group and confirms' do
    visit reaffecter_dossiers_admin_procedure_groupe_instructeur_path(procedure, groupe)

    expect(page).to have_content("Réaffectation des dossiers du groupe « #{groupe.label} »")
    expect(page).to have_button('Réaffecter les dossiers à ce groupe', disabled: true)

    select_react_option('deuxième groupe', from: 'Nouveau groupe instructeur')

    expect(page).to have_button('Réaffecter les dossiers à ce groupe', disabled: false)

    accept_confirm { click_on 'Réaffecter les dossiers à ce groupe' }

    expect(page).to have_content("Les dossiers du groupe « #{groupe.label} » ont été réaffectés au groupe « deuxième groupe »")
    expect(dossiers.map { it.reload.groupe_instructeur }).to all(eq(autre_groupe))
  end
end
