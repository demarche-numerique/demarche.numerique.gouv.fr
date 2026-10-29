# frozen_string_literal: true

describe 'Export banner:', js: true do
  let(:instructeur) { create(:instructeur) }
  let(:colleague) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, instructeurs: [instructeur, colleague]) }
  let(:other_procedure) { create(:procedure, :published, instructeurs: [instructeur, colleague]) }
  let(:gi) { procedure.defaut_groupe_instructeur }
  let!(:dossier) { create(:dossier, :en_construction, procedure:) }

  before { suppress_turbo_poll }

  scenario 'the requester keeps the banner on another procedure' do
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedure_path(procedure)
    click_on "Télécharger un dossier"
    within(:css, '#tabpanel-standard1-panel') do
      choose "Fichier csv", allow_label_click: true
      click_on "Demander l’export"
    end
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

    export.file.attach(io: StringIO.new('x'), filename: 'e.csv')
    export.update!(job_status: :generated)
    visit instructeur_procedure_path(other_procedure)
    expect(page).to have_css('#export-banner .alert-success', text: 'Le dernier export au format csv est prêt.')
  end

  scenario 'an action flash stacks above the export banner' do
    instructeur.request_export!(create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur))
    login_as(instructeur.user, scope: :user)
    visit instructeur_procedure_path(procedure)
    click_on 'Suivre'

    expect(page).to have_css('#flash_messages', text: 'Dossier suivi')
    expect(page).to have_css('#export-banner .alert-info')
    expect(page).to have_css('#flash_messages + #export-banner')
  end
end
