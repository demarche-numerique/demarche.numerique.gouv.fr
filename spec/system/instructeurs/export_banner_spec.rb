# frozen_string_literal: true

describe 'Export banner:', js: true do
  let(:instructeur) { instructeurs.default }
  let(:colleague) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, instructeurs: [instructeur, colleague]) }
  let(:other_procedure) { create(:procedure, :published, instructeurs: [instructeur, colleague]) }
  let(:gi) { procedure.defaut_groupe_instructeur }
  let!(:dossier) { create(:dossier, :en_construction, procedure:) }

  before { suppress_turbo_poll }

  def request_csv_export
    click_on "Télécharger un dossier"
    within(:css, '#tabpanel-standard1-panel') do
      choose "Fichier csv", allow_label_click: true
      click_on "Demander l’export"
    end
  end

  def ready(export)
    export.file.attach(io: StringIO.new('x'), filename: 'e.csv')
    export.update!(job_status: :generated)
    export
  end

  scenario 'the requester keeps the banner on another procedure' do
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedure_path(procedure)
    request_csv_export
    expect(page).to have_css('#export-banner .alert-info')
    expect(page).to have_css('#export-banner:focus')

    visit instructeur_procedure_path(other_procedure)
    expect(page).to have_css('#export-banner .alert-info', text: 'Votre dernier export est en cours de création.')
  end

  scenario 'a colleague sees the ready export, not the pending one' do
    export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
    login_as(colleague.user, scope: :user)
    visit instructeur_procedure_path(procedure)
    expect(page).to have_no_css('#export-banner .alert')

    ready(export)
    visit instructeur_procedure_path(other_procedure)
    expect(page).to have_css('#export-banner .alert-success', text: "Le dernier export au format csv, demandé par #{instructeur.email}, est prêt.")
  end

  scenario 'an action flash stacks above the export banner' do
    create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
    instructeur.request_export!
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedure_path(procedure)
    click_on 'Suivre'

    expect(page).to have_css('#flash_messages', text: 'Dossier suivi')
    expect(page).to have_css('#export-banner .alert-info')
    expect(page).to have_css('#flash_messages + #export-banner')
  end

  scenario 'closing a banner hides all earlier exports across pages until a new export is ready' do
    travel_to(2.minutes.ago) do
      ready(create(:export, groupe_instructeurs: [gi], user_profile: instructeur))
      ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
    end
    own = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
    instructeur.request_export!
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedure_path(procedure)
    expect(page).to have_css("#export-banner-#{own.id}.alert-info")

    within('#export-banner') { click_on 'Masquer le message' }
    expect(page).to have_no_css('#export-banner .alert')
    page.refresh
    expect(page).to have_no_css('#export-banner .alert')
    visit instructeur_procedure_path(other_procedure)
    expect(page).to have_no_css('#export-banner .alert')

    latest = ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
    page.refresh
    expect(page).to have_css("#export-banner-#{latest.id}.alert-success")
    expect(page).to have_css('#export-banner .alert', count: 1)
  end

  scenario 'a failed export reappears after its pending banner was closed' do
    own = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
    instructeur.request_export!
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedure_path(procedure)

    within('#export-banner') { click_on 'Masquer le message' }
    expect(page).to have_no_css('#export-banner .alert')
    page.refresh
    expect(page).to have_no_css('#export-banner .alert')

    own.update!(job_status: :failed)
    visit instructeur_procedure_path(other_procedure)
    expect(page).to have_css("#export-banner-#{own.id}.alert-danger", text: 'Votre dernier export au format csv n’a pas pu être créé.')
    within('#export-banner') { click_on 'Masquer le message' }
    expect(page).to have_no_css('#export-banner .alert')
    page.refresh
    expect(page).to have_no_css('#export-banner .alert')
  end

  scenario 'requesting the same ready export reopens its banner without creating another export' do
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedure_path(procedure)
    request_csv_export
    expect(page).to have_css('#export-banner .alert-info')
    export = Export.where(user_profile: instructeur).sole
    ready(export)
    page.refresh
    expect(page).to have_css("#export-banner-#{export.id}.alert-success")

    within('#export-banner') { click_on 'Masquer le message' }
    expect(page).to have_no_css('#export-banner .alert')
    request_csv_export

    expect(page).to have_css("#export-banner-#{export.id}.alert-success")
    expect(page).to have_css('#export-banner:focus')
    expect(Export.where(user_profile: instructeur).pluck(:id)).to eq([export.id])
    within('#export-banner') { click_on 'Masquer le message' }
    expect(page).to have_no_css('#export-banner .alert')
    page.refresh
    expect(page).to have_no_css('#export-banner .alert')
  end

  scenario 'the own pending export keeps priority and becomes ready through polling without moving focus' do
    own = travel_to(2.minutes.ago) { create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur) }
    ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
    instructeur.request_export!
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedure_path(procedure)
    expect(page).to have_css("#export-banner-#{own.id}.alert-info")
    page.execute_script('document.getElementById("download_menu_button").focus()')
    expect(page).to have_css('#download_menu_button:focus')

    ready(own)
    with_turbo_poll do
      expect(page).to have_css("#export-banner-#{own.id}.alert-success", wait: 10)
    end

    expect(page).to have_css('#export-banner .alert', count: 1)
    expect(page).to have_css('#download_menu_button:focus')
  end
end
