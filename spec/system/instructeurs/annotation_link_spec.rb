# frozen_string_literal: true

describe 'Private link annotation', js: true do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) do
    create(:procedure, :published, instructeurs: [instructeur], private_type_de_champs: [{ type: :link, libelle: 'Requête dans Astrée', description: 'Lien renseigné par Astrée' }])
  end
  let(:dossier) { create(:dossier, :en_instruction, procedure:) }
  let(:champ) { dossier.root_champs_private.first }
  let(:url) { 'https://astree.exemple.gouv.fr/requetes/TA-2026-0421' }
  let(:new_url) { 'https://astree.exemple.gouv.fr/requetes/TA-2026-0999' }

  before { login_as(instructeur.user, scope: :user) }

  scenario 'a filled link is edited, then saved' do
    champ.update!(value: url)
    visit annotations_privees_instructeur_dossier_path(procedure, dossier)

    expect(page).to have_link(url, href: url)
    expect(page).to have_no_css('input[type=url]', visible: true)

    click_on 'Modifier le lien'
    expect(page).to have_css('input[type=url]:focus')
    fill_in 'Requête dans Astrée', with: 'astree.exemple.gouv.fr/requetes/TA-2026-0999'
    expect(champ.reload.value).to eq(url) # typing does not save

    click_on 'Enregistrer'
    expect(page).to have_link(new_url, href: new_url)
    expect(page).to have_css('button:focus', text: 'Modifier le lien')
    expect(champ.reload.value).to eq(new_url)
  end

  scenario 'editing a link is cancelled' do
    champ.update!(value: url)
    visit annotations_privees_instructeur_dossier_path(procedure, dossier)

    click_on 'Modifier le lien'
    fill_in 'Requête dans Astrée', with: new_url
    within('.fr-callout') { click_on 'Annuler' }

    expect(page).to have_link(url, href: url)
    expect(page).to have_css('button:focus', text: 'Modifier le lien')
    expect(champ.reload.value).to eq(url)
  end

  scenario 'an empty link is filled, then saved' do
    visit annotations_privees_instructeur_dossier_path(procedure, dossier)

    expect(page).to have_no_button('Annuler', visible: true)
    fill_in 'Requête dans Astrée', with: url
    click_on 'Enregistrer'

    expect(page).to have_link(url, href: url)
    expect(champ.reload.value).to eq(url)
  end

  scenario 'an url that is not http(s) is rejected' do
    visit annotations_privees_instructeur_dossier_path(procedure, dossier)

    fill_in 'Requête dans Astrée', with: 'javascript:alert(1)'
    click_on 'Enregistrer'

    expect(page).to have_content('n’est pas un lien valide')
    expect(page).to have_field('Requête dans Astrée', with: 'javascript:alert(1)', visible: true)
    expect(page).to have_no_link(href: /javascript/)
  end
end
