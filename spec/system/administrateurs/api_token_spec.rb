# frozen_string_literal: true

describe 'As an administrateur I create an API token', js: true do
  include SystemHelpers
  let(:administrateur) { procedure.administrateurs.first }
  let(:procedure) { create(:procedure) }

  before do
    # Pin the cap so the suite does not depend on the local configuration.
    stub_const('APIToken::MAX_LIFETIME', 365.days)
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

  scenario 'token creation with auto-assign IP' do
    visit profil_path
    expect(page).to have_content('Profil')

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'mon jeton'
    click_on 'Continuer'

    custom_check "target_custom"
    select "#{procedure.id} - #{procedure.libelle}"
    click_on 'Ajouter'
    custom_check 'access_read_write'
    click_on 'Continuer'
    expect(page).to have_content("Sécurité")

    custom_check 'networkFiltering_autoassign'
    custom_check 'lifetime_oneweek'
    click_on('Créer le jeton')
    expect(page).to have_content("Votre jeton est prêt")

    token = APIToken.last
    expect(token.requires_ip_filtering).to be true
    expect(token.authorized_networks).to be_empty
  end

  scenario 'token creation with manual IP' do
    visit profil_path

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'jeton manuel'
    click_on 'Continuer'

    custom_check 'access_read_write'
    custom_check 'target_all'
    click_on 'Continuer'
    expect(page).to have_content("Sécurité")

    custom_check 'networkFiltering_customnetworks'
    fill_in 'networks', with: '192.168.1.0/24'
    custom_check 'lifetime_oneweek'
    click_on('Créer le jeton')
    expect(page).to have_content("Votre jeton est prêt")

    token = APIToken.last
    expect(token.requires_ip_filtering).to be true
    expect(token.authorized_networks).to eq([IPAddr.new('192.168.1.0/24')])
  end
  scenario 'token creation with a preset lifetime, no eternal option offered' do
    visit profil_path

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'jeton semestriel'
    click_on 'Continuer'

    custom_check 'access_read_write'
    custom_check 'target_all'
    click_on 'Continuer'
    expect(page).to have_content("Sécurité")

    expect(page).to have_no_content('Infini')

    custom_check 'networkFiltering_autoassign'
    custom_check 'lifetime_sixmonths'
    click_on('Créer le jeton')
    expect(page).to have_content("Votre jeton est prêt")

    expect(APIToken.last.expires_at).to eq(APIToken::LIFETIMES[:sixMonths].from_now.to_date)
  end

  scenario 'token creation with a custom lifetime' do
    visit profil_path

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'jeton daté'
    click_on 'Continuer'

    custom_check 'access_read_write'
    custom_check 'target_all'
    click_on 'Continuer'
    expect(page).to have_content("Sécurité")

    custom_check 'networkFiltering_autoassign'
    custom_check 'lifetime_custom'
    fill_in 'customLifetime', with: 3.months.from_now.to_date.iso8601
    click_on('Créer le jeton')
    expect(page).to have_content("Votre jeton est prêt")

    expect(APIToken.last.expires_at).to eq(3.months.from_now.to_date)
  end

  scenario 'going back through the steps preserves previously entered data' do
    visit profil_path

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'jeton avec retour'
    click_on 'Continuer'

    custom_check 'target_custom'
    select "#{procedure.id} - #{procedure.libelle}", from: 'procedureSelect'
    click_on 'Ajouter'
    custom_check 'access_read_write'
    click_on 'Continuer'
    expect(page).to have_content('Sécurité')

    click_on 'Retour'
    expect(page).to have_content('Privilèges du jeton')
    expect(page).to have_checked_field('access_read_write')
    expect(page).to have_text(procedure.libelle)

    click_on 'Retour'
    expect(page).to have_field('Nom du jeton', with: 'jeton avec retour')

    click_on 'Continuer'
    expect(page).to have_checked_field('access_read_write')
    expect(page).to have_text(procedure.libelle)
    click_on 'Continuer'
    expect(page).to have_content('Sécurité')

    custom_check 'networkFiltering_customnetworks'
    fill_in 'networks', with: '192.168.1.0/24'
    custom_check 'lifetime_oneweek'

    click_on('Créer le jeton')
    expect(page).to have_content('Votre jeton est prêt')

    token = APIToken.last
    expect(token.authorized_networks).to eq([IPAddr.new('192.168.1.0/24')])
  end

  scenario 'duplicating a token pre-fills steps 1 and 2 but leaves lifetime blank' do
    original_token = APIToken.generate(administrateur).first
    original_token.update!(name: 'Jeton original', write_access: true, allowed_procedure_ids: [procedure.id], authorized_networks: [IPAddr.new('192.168.1.0/24')])

    visit profil_path
    click_on 'Dupliquer'

    expect(page).to have_field('Nom du jeton', with: 'Jeton original')
    click_on 'Continuer'

    expect(page).to have_checked_field('access_read_write')
    expect(page).to have_text(procedure.libelle)
    click_on 'Continuer'

    expect(page).to have_content('Sécurité')
    expect(page).to have_checked_field('networkFiltering_customnetworks')
    expect(page).to have_field('networks', with: '192.168.1.0/24')
    expect(page).to have_no_checked_field('lifetime_oneweek')
    expect(page).to have_no_checked_field('lifetime_custom')
  end

  scenario 'restricting and restoring access to an api token' do
    token = APIToken.generate(administrateur).first
    visit edit_admin_api_token_path(token)

    expect(page).to have_content('accès à toutes vos démarches')
    click_on "Restreindre lʼaccès à certaines démarches"

    select "#{procedure.id} - #{procedure.libelle}", from: 'procedure_to_add'
    click_on 'Ajouter'

    expect(page).to have_content(procedure.libelle)
    expect(token.reload.allowed_procedure_ids).to eq([procedure.id])

    click_on 'Supprimer'

    expect(page).to have_no_css("li#authorized_procedure_#{procedure.id}")
    expect(token.reload.allowed_procedure_ids).to be_nil

    visit edit_admin_api_token_path(token)

    expect(page).to have_content('accès à toutes vos démarches')
  end
end
