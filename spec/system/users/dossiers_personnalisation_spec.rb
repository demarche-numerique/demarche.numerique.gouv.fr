# frozen_string_literal: true

describe 'Personnaliser la liste des dossiers ETQ usager', type: :system, js: true do
  let(:user) { create(:user) }
  let(:procedure) do
    create(:procedure, :published, libelle: 'Aide à la presse', types_de_champ_public: [
      { type: :text, libelle: 'Titre de la publication' },
      { type: :text, libelle: 'Numéro de CPPAP' },
    ])
  end

  before do
    create_list(:dossier, 6, user:, procedure:).each_with_index do |dossier, i|
      titre = dossier.champs.find { _1.libelle == 'Titre de la publication' }
      titre&.update!(value: "Presse n°#{i}")
    end
    login_as(user, scope: :user)
  end

  scenario "l'usager personnalise sa liste de dossiers" do
    visit dossiers_path

    expect(page).to have_link(href: edit_users_dossiers_personnalisation_path)

    visit edit_users_dossiers_personnalisation_path

    expect(page).to have_content('Personnaliser la liste des dossiers')
    expect(page).to have_button('Enregistrer', disabled: true)

    within(:fieldset, text: 'Aide à la presse') do
      find('.fr-autocomplete').click
    end

    find('[role=option]', text: 'Titre de la publication').click
    find('[role=option]', text: 'Numéro de CPPAP').click

    expect(page).to have_button('Enregistrer', disabled: false)

    click_button 'Enregistrer'

    expect(page).to have_content('La liste des dossiers a bien été personnalisée.')
    expect(page).to have_content('Presse n°0')
  end

  scenario "l'icône n'apparaît pas pour un usager avec 5 dossiers ou moins" do
    user.dossiers.first.update!(hidden_by_user_at: Time.current)
    visit dossiers_path
    expect(page).not_to have_link(href: edit_users_dossiers_personnalisation_path)
  end
end
