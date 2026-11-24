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

    visit nom_admin_api_tokens_path
    fill_in 'Nom du jeton', with: 'test-xss'
    click_on 'Continuer'
    custom_check 'api_token_form_target_custom'
    expect(page).to have_field('Sélectionner les démarches autorisées', visible: true)

    fill_in 'Sélectionner les démarches autorisées', with: procedure.libelle
    find('[role="option"]', text: procedure.libelle).click

    expect(page).to have_text(xss_payload)
    expect(page).to have_no_css('img[src="x"]')
  end

  scenario 'token creation with auto-assign IP' do
    visit profil_path
    expect(page).to have_content('Profil')

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'mon jeton'
    click_on 'Continuer'

    custom_check "api_token_form_target_custom"
    fill_in 'Sélectionner les démarches autorisées', with: procedure.libelle
    find('[role="option"]', text: procedure.libelle).click
    send_keys(:escape)
    custom_check 'api_token_form_access_read_write'
    click_on 'Continuer'
    expect(page).to have_content("Sécurité")

    custom_check 'api_token_form_network_filtering_autoassign'
    custom_check 'api_token_form_lifetime_oneweek'
    click_on('Valider')
    expect(page).to have_content("Votre jeton est prêt")
    expect(page).to have_text("#{procedure.libelle} et ses futurs clones")

    token = APIToken.last
    expect(token.requires_ip_filtering).to be true
    expect(token.authorized_networks).to be_empty
    expect(token.allowed_procedure_ids).to eq([procedure.id])
    expect(token.follows_clones).to be true
  end

  scenario 'token creation with manual IP' do
    visit profil_path

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'jeton manuel'
    click_on 'Continuer'

    custom_check 'api_token_form_access_read_write'
    custom_check 'api_token_form_target_all'
    click_on 'Continuer'
    expect(page).to have_content("Sécurité")

    custom_check 'api_token_form_network_filtering_customnetworks'
    fill_in 'api_token_form_networks', with: '192.168.1.0/24'
    custom_check 'api_token_form_lifetime_oneweek'
    click_on('Valider')
    expect(page).to have_content("Votre jeton est prêt")

    token = APIToken.last
    expect(token.requires_ip_filtering).to be true
    expect(token.authorized_networks).to eq([IPAddr.new('192.168.1.0/24')])
    expect(token.follows_clones).to be false
  end
  scenario 'token creation with a preset lifetime, no eternal option offered' do
    visit profil_path

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'jeton semestriel'
    click_on 'Continuer'

    custom_check 'api_token_form_access_read_write'
    custom_check 'api_token_form_target_all'
    click_on 'Continuer'
    expect(page).to have_content("Sécurité")

    expect(page).to have_no_content('Infini')

    custom_check 'api_token_form_network_filtering_autoassign'
    custom_check 'api_token_form_lifetime_sixmonths'
    click_on('Valider')
    expect(page).to have_content("Votre jeton est prêt")

    expect(APIToken.last.expires_at).to eq(APIToken::LIFETIMES[:sixMonths].from_now.to_date)
  end

  scenario 'token creation with a custom lifetime' do
    visit profil_path

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'jeton daté'
    click_on 'Continuer'

    custom_check 'api_token_form_access_read_write'
    custom_check 'api_token_form_target_all'
    click_on 'Continuer'
    expect(page).to have_content("Sécurité")

    custom_check 'api_token_form_network_filtering_autoassign'
    custom_check 'api_token_form_lifetime_custom'
    fill_in 'api_token_form_custom_lifetime', with: 3.months.from_now.to_date.iso8601
    click_on('Valider')
    expect(page).to have_content("Votre jeton est prêt")

    expect(APIToken.last.expires_at).to eq(3.months.from_now.to_date)
  end

  scenario 'going back through the steps preserves previously entered data' do
    visit profil_path

    click_on 'Créer un nouveau jeton'
    fill_in 'Nom du jeton', with: 'jeton avec retour'
    click_on 'Continuer'

    custom_check 'api_token_form_target_custom'
    fill_in 'Sélectionner les démarches autorisées', with: procedure.libelle
    find('[role="option"]', text: procedure.libelle).click
    send_keys(:escape)
    custom_check 'api_token_form_access_read_write'
    expect(page).to have_checked_field('api_token_form_follows_clones')
    custom_check 'api_token_form_follows_clones'
    click_on 'Continuer'
    expect(page).to have_content('Sécurité')

    click_on 'Retour'
    expect(page).to have_content('Privilèges du jeton')
    expect(page).to have_checked_field('api_token_form_access_read_write')
    expect(page).to have_unchecked_field('api_token_form_follows_clones')
    expect(page).to have_text(procedure.libelle)

    click_on 'Retour'
    expect(page).to have_field('Nom du jeton', with: 'jeton avec retour')

    click_on 'Continuer'
    expect(page).to have_checked_field('api_token_form_access_read_write')
    expect(page).to have_text(procedure.libelle)
    click_on 'Continuer'
    expect(page).to have_content('Sécurité')

    custom_check 'api_token_form_network_filtering_customnetworks'
    fill_in 'api_token_form_networks', with: '192.168.1.0/24'
    custom_check 'api_token_form_lifetime_oneweek'

    click_on('Valider')
    expect(page).to have_content('Votre jeton est prêt')

    token = APIToken.last
    expect(token.authorized_networks).to eq([IPAddr.new('192.168.1.0/24')])
    expect(token.follows_clones).to be false
  end

  scenario 'duplicating a token pre-fills steps 1 and 2 but leaves lifetime blank' do
    original_token = APIToken.generate(administrateur).first
    original_token.update!(name: 'Jeton original', write_access: true, allowed_procedure_ids: [procedure.id], authorized_networks: [IPAddr.new('192.168.1.0/24')])

    visit profil_path
    click_on 'Dupliquer'

    expect(page).to have_field('Nom du jeton', with: 'Jeton original')
    expect(URI(page.current_url).query).to be_nil
    click_on 'Continuer'

    expect(page).to have_checked_field('api_token_form_access_read_write')
    expect(page).to have_unchecked_field('api_token_form_follows_clones')
    expect(page).to have_text(procedure.libelle)
    expect(URI(page.current_url).query).to be_nil
    click_on 'Continuer'

    expect(page).to have_content('Sécurité')
    expect(URI(page.current_url).query).to be_nil
    expect(page).to have_checked_field('api_token_form_network_filtering_customnetworks')
    expect(page).to have_field('api_token_form_networks', with: '192.168.1.0/24')
    expect(page).to have_no_checked_field('api_token_form_lifetime_oneweek')
    expect(page).to have_no_checked_field('api_token_form_lifetime_custom')
  end

  scenario 'duplicating a list token whose procedures are all binned selects none' do
    original_token = APIToken.generate(administrateur).first
    original_token.update!(allowed_procedure_ids: [procedure.id])
    procedure.discard!

    visit profil_path
    click_on 'Dupliquer'
    click_on 'Continuer'

    expect(page).to have_checked_field('api_token_form_target_custom')
    expect(page).to have_field('Sélectionner les démarches autorisées')
    expect(page).to have_button('Continuer', disabled: true)
  end

  scenario 'copying the token of a co-administrateur' do
    co_admin = administrateurs.blank
    procedure.administrateurs << co_admin
    APIToken.generate(co_admin, name: 'Jeton du collègue', write_access: false, allowed_procedure_ids: [procedure.id], authorized_networks: [IPAddr.new('192.168.1.0/24')])

    visit profil_path
    click_on 'Dupliquer'

    expect(page).to have_field('Nom du jeton', with: 'Jeton du collègue (copie)')
    click_on 'Continuer'

    expect(page).to have_text("Copie du jeton « Jeton du collègue » de #{co_admin.email}")
    expect(page).to have_checked_field('api_token_form_access_read')
    click_on 'Continuer'

    expect(page).to have_field('api_token_form_networks', with: '192.168.1.0/24')
    custom_check 'api_token_form_lifetime_oneweek'
    click_on 'Valider'

    expect(page).to have_content('Votre jeton est prêt')
    expect(administrateur.api_tokens.sole).to have_attributes(allowed_procedure_ids: [procedure.id], write_access: false, authorized_networks: [IPAddr.new('192.168.1.0/24')])
  end

  scenario 'seeing every procedure a token reads' do
    APIToken.generate(administrateur, name: 'Export', allowed_procedure_ids: [procedures.individual, procedures.brouillon, procedures.close, procedure].map(&:id))

    visit profil_path
    expect(page).to have_text('4 démarches')
    click_on 'Voir le détail'

    within('dialog[open]') do
      expect(page).to have_text('Jeton « Export »')
      expect(page).to have_link(procedure.libelle, href: admin_procedure_path(procedure))
    end
  end

  scenario 'restricting and restoring access to an api token' do
    token = APIToken.generate(administrateur).first
    visit edit_admin_api_token_path(token)

    expect(page).to have_content('accès à toutes vos démarches')
    click_on "Restreindre lʼaccès à certaines démarches"

    click_on 'Ajouter'

    expect(page).to have_css('#flash_messages:focus', text: 'Choisissez une démarche à ajouter.')
    expect(page).to have_select('procedure_to_add')

    select "#{procedure.id} - #{procedure.libelle}", from: 'procedure_to_add'
    click_on 'Ajouter'

    expect(page).to have_css('#flash_messages:focus', text: "La démarche « #{procedure.libelle} » a été ajoutée au jeton.")
    expect(page).to have_css("li#authorized_procedure_#{procedure.id}")
    expect(token.reload.allowed_procedure_ids).to eq([procedure.id])

    custom_check 'follows_clones'

    expect(page).to have_css('form[data-turbo-confirm]')
    expect(token.reload.follows_clones).to be true

    accept_confirm { click_on 'Supprimer' }

    expect(page).to have_no_css("li#authorized_procedure_#{procedure.id}")
    expect(token.reload.allowed_procedure_ids).to eq([])

    click_on "Restaurer lʼaccès à toutes les démarches"

    expect(page).to have_no_content('Votre jeton dʼAPI a accès à certaines démarches')
    expect(page).to have_content('accès à toutes vos démarches')
    expect(token.reload.allowed_procedure_ids).to be_nil
  end
end
