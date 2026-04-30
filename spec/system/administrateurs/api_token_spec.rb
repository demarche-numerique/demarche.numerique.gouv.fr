# frozen_string_literal: true

describe 'As an administrateur I create an API token', js: true do
  include SystemHelpers
  let(:administrateur) { procedure.administrateurs.first }
  let(:procedure) { create(:procedure) }

  before do
    login_as administrateur.user, scope: :user
  end
  scenario 'procedure libelle with HTML is escaped when added to authorized list (XSS prevention)' do
    xss_payload = '<img src=x onerror=alert(1)>'
    procedure.update_column(:libelle, xss_payload)

    visit profil_path
    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'test-xss'
    click_on 'Continuer'

    custom_check "target_custom"
    select "#{procedure.id} - #{xss_payload}", from: 'procedureSelect'
    click_on 'Ajouter'

    expect(page).to have_text(xss_payload)
    expect(page).to have_no_css('img[src="x"]')
  end

  scenario 'token creation' do
    visit profil_path
    expect(page).to have_content('Profil')

    click_on 'Créer un nouveau jeton'
    expect(page).to have_content("Création d’un nouveau jeton")

    fill_in 'Nom du jeton', with: 'mon jeton'
    click_on 'Continuer'
    expect(page).to have_content("Privilèges du jeton « mon jeton »")

    custom_check "target_custom"
    select "#{procedure.id} - #{procedure.libelle}"
    click_on 'Ajouter'
    custom_check 'access_read_write'
    click_on 'Continuer'
    expect(page).to have_content("Sécurité")

    custom_check 'networkFiltering_none'
    custom_check 'lifetime_oneweek'
    click_on('Créer le jeton')
    expect(page).to have_content("Votre jeton est prêt")
  end
end
