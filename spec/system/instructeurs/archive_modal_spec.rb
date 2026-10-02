# frozen_string_literal: true

describe 'Archive warning modal', js: true do
  include ActionView::RecordIdentifier

  let(:password) { 'demarches-simplifiees' }
  let(:instructeur) { create(:instructeur, password:) }
  let(:procedure) { create(:simple_procedure, :published, instructeurs: [instructeur], administrateurs: [administrateurs.default]) }
  let!(:dossier_1) { create(:dossier, :accepte, procedure:) }
  let!(:dossier_2) { create(:dossier, :accepte, procedure:) }

  before { log_in(instructeur.email, password) }

  scenario 'archiving from the dossier page warns once the instructeur asks to stop' do
    visit instructeur_dossier_path(procedure, dossier_1)

    open_dsfr_modal('#modal-archive') { click_on 'Déplacer dans “à archiver“' }
    within('#modal-archive') do
      expect(page).to have_content('Information importante')
      check('Ne plus afficher cette information', allow_label_click: true)
      click_on 'Annuler'
    end
    expect(page).to have_no_selector('#modal-archive', visible: :visible)
    expect(page).to have_button('Déplacer dans “à archiver“')
    expect(dossier_1.reload.archived).to be(false)
    expect(instructeur.reload.archive_warning_dismissed).to be(false)

    open_dsfr_modal('#modal-archive') { click_on 'Déplacer dans “à archiver“' }
    within('#modal-archive') do
      check('Ne plus afficher cette information', allow_label_click: true)
      click_on 'Confirmer'
    end
    expect(page).to have_button('Replacer dans “traités”')
    expect(dossier_1.reload.archived).to be(true)
    expect(instructeur.reload.archive_warning_dismissed).to be(true)

    visit instructeur_dossier_path(procedure, dossier_2)
    expect(page).not_to have_selector('#modal-archive', visible: :all)
    click_on 'Déplacer dans “à archiver“'
    expect(page).to have_button('Replacer dans “traités”')
    expect(dossier_2.reload.archived).to be(true)
  end

  scenario 'archiving from the traites table targets the clicked dossier', :allow_forgery_protection do
    visit instructeur_procedure_path(procedure, statut: 'traites')

    row = find("##{dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")}").ancestor('tr')
    open_dsfr_modal('#modal-archive') { within(row) { click_on 'Déplacer dans “à archiver“' } }
    within('#modal-archive') { click_on 'Confirmer' }

    expect(page).not_to have_selector("##{dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")}")
    expect(dossier_2.reload.archived).to be(true)
    expect(dossier_1.reload.archived).to be(false)
    expect(instructeur.reload.archive_warning_dismissed).to be(false)
  end

  scenario 'Escape from the dismiss checkbox closes the modal and gives focus back' do
    visit instructeur_dossier_path(procedure, dossier_1)

    open_dsfr_modal('#modal-archive') { click_on 'Déplacer dans “à archiver“' }
    find('#modal-archive-dismiss', visible: :all).send_keys(:escape)

    expect(page).to have_no_selector('#modal-archive', visible: :visible)
    expect(page).to have_selector('[aria-controls="modal-archive"]:focus')
    expect(dossier_1.reload.archived).to be(false)
  end

  scenario 'batch archiving shows the modal instead of the browser confirm' do
    suppress_turbo_poll
    visit instructeur_procedure_path(procedure, statut: 'traites')

    check(dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}"))
    check(dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}"))
    open_dsfr_modal('#modal-archive-batch') { click_on 'Déplacer les dossiers dans “à archiver“' }
    within('#modal-archive-batch') { click_on 'Confirmer' }

    expect(page).to have_content('dossiers sont en cours de déplacement dans « à archiver »')
    expect(BatchOperation.last.operation).to eq('archiver')
    expect(BatchOperation.last.dossiers).to match_array([dossier_1, dossier_2])
    expect(instructeur.reload.archive_warning_dismissed).to be(false)
  end

  def log_in(email, password)
    visit new_user_session_path
    expect(page).to have_current_path(new_user_session_path)

    sign_in_with(email, password)

    expect(page).to have_current_path(instructeur_procedures_path)
  end
end
