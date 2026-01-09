# frozen_string_literal: true

describe 'Instructing a dossier:', js: true do
  include ActiveJob::TestHelper
  include Logic
  include ZipHelpers

  let(:password) { SECURE_PASSWORD }
  let!(:instructeur) { create(:instructeur, password: password) }

  let!(:procedure) { create(:procedure, :published, instructeurs: [instructeur], types_de_champ_private: [{ type: 'checkbox', libelle: 'Yes/No', stable_id: 99 }, { libelle: 'Nom', condition: ds_eq(champ_value(99), constant(true)) }]) }
  let!(:dossier) { create(:dossier, :en_construction, :with_entreprise, procedure: procedure) }

  scenario 'A instructeur can signin by email' do
    log_in(instructeur.email, password, check_email: true)
    expect(page).to have_current_path(instructeur_procedures_path)
  end

  context 'the instructeur is also a user' do
    scenario 'a instructeur can fill a dossier' do
      visit commencer_path(path: procedure.path)
      click_on 'J’ai déjà un compte'

      expect(page).to have_current_path new_user_session_path
      sign_in_with(instructeur.email, password, true)

      # connexion link erase user stored location
      # expect(page).to have_current_path(commencer_path(path: procedure.path))

      visit commencer_path(path: procedure.path)
      click_on 'Commencer la démarche'

      expect(page).to have_content('Identifier votre établissement')
      expect(page).to have_current_path(siret_dossier_path(procedure.reload.dossiers.last))
      expect(page).to have_content(procedure.libelle)
    end
  end

  scenario 'A instructeur can accept a dossier' do
    log_in(instructeur.email, password)

    expect(page).to have_current_path(instructeur_procedures_path)

    click_on(procedure.libelle, visible: true)
    expect(page).to have_current_path(instructeur_procedure_path(procedure))

    click_on dossier.user.email
    expect(page).to have_current_path(instructeur_dossier_path(procedure, dossier, statut: 'a-suivre'))
    page.find('.back-btn').click

    click_on 'Suivre'
    click_on 'suivi'
    expect(page).to have_current_path(instructeur_procedure_path(procedure, statut: 'suivis'))

    click_on dossier.user.email
    expect(page).to have_current_path(instructeur_dossier_path(procedure, 'suivis', dossier))
    expect(page).to have_selector(".back-btn[href=\"#{instructeur_procedure_path(procedure, statut: 'suivis')}\"]")

    click_on 'Passer en instruction'

    expect(page).to have_text('Dossier passé en instruction.')
    expect(page).to have_text('Instruire le dossier')
    expect(page).to have_selector('.fr-badge', text: 'en instruction')

    dossier.reload
    expect(dossier.state).to eq(Dossier.states.fetch(:en_instruction))

    click_on 'Instruire le dossier'

    within('.instruction-button') do
      # FIXME click_on 'Accepter' is not working for some reason
      find_link('Accepter').click
    end

    within('.accept.motivation') do
      fill_in('dossier_motivation', with: 'a good reason')

      accept_confirm do
        click_on 'Valider la décision'
      end
    end

    expect(page).to have_text('Dossier traité avec succès.')
    expect(page).to have_button('Déplacer dans “à archiver“')

    dossier.reload
    expect(dossier.state).to eq(Dossier.states.fetch(:accepte))
    expect(dossier.motivation).to eq('a good reason')
    # keep back up to date after most action on dossier
    expect(page).to have_selector(".back-btn[href=\"#{instructeur_procedure_path(procedure, statut: 'suivis')}\"]")

    click_on(procedure.libelle, visible: true)
    click_on 'traité'
    expect(page).to have_button('Repasser en instruction')
    click_on 'Mettre à la corbeille'
    expect(page).not_to have_button('Repasser en instruction')
  end

  scenario 'An instructeur can add annotations' do
    log_in(instructeur.email, password)

    visit instructeur_dossier_path(procedure, dossier)
    click_on 'Annotations privées'

    expect(page).not_to have_field 'Nom', visible: true
    check 'Yes/No', allow_label_click: true
    expect(page).to have_field 'Nom'
    fill_in 'Nom', with: 'John Doe'
    expect(page).to have_text 'Annotations enregistrées'
  end

  scenario 'A instructeur can follow/unfollow a dossier' do
    log_in(instructeur.email, password)

    click_on(procedure.libelle, visible: true)
    test_statut_bar(a_suivre: 1, tous_les_dossiers: 1)
    dossier_present?(dossier.id, 'en construction')

    click_on 'Suivre'
    expect(page).to have_current_path(instructeur_procedure_path(procedure))
    test_statut_bar(suivi: 1, tous_les_dossiers: 1)
    expect(page).to have_text('Aucun dossier')

    click_on 'suivis par moi'
    expect(page).to have_current_path(instructeur_procedure_path(procedure, statut: 'suivis'))
    dossier_present?(dossier.id, 'en construction')

    click_on 'Ne plus suivre'
    expect(page).to have_current_path(instructeur_procedure_path(procedure, statut: 'suivis'))
    test_statut_bar(a_suivre: 1, tous_les_dossiers: 1)
    expect(page).to have_text('Aucun dossier')
  end

  scenario 'A instructeur can request an export' do
    log_in(instructeur.email, password)

    click_on(procedure.libelle, visible: true)
    test_statut_bar(a_suivre: 1, tous_les_dossiers: 1)

    click_on "Télécharger un dossier"
    within(:css, '#tabpanel-standard1-panel') do
      choose "Fichier csv", allow_label_click: true
      click_on "Demander l’export"
    end

    expect(page).to have_text('Nous générons cet export.')

    find("button", text: "Téléchargements").click
    click_on "Liste des exports"
    expect(page).to have_text("Export .csv d’un dossier « à suivre » demandé il y a moins d’une minute")
    expect(page).to have_text("En préparation")

    assert_performed_jobs 1 do
      perform_enqueued_jobs(only: ExportJob)
    end

    page.refresh
    expect(page).to have_text('Télécharger l’export')
  end

  scenario 'A instructeur can see the personnes impliquées and statut is maintened over avis/personnes impliquee paths' do
    instructeur2 = create(:instructeur, password: password)

    log_in(instructeur.email, password)

    click_on(procedure.libelle, visible: true)
    click_on 'Suivre'
    click_on 'suivi'
    click_on dossier.user.email

    click_on 'Avis externes'
    expect(page).to have_current_path(avis_instructeur_dossier_path(procedure, dossier, statut: 'suivis'))
    within('.fr-sidemenu') { click_on 'Demander un avis' }
    expect(page).to have_current_path(avis_new_instructeur_dossier_path(procedure, dossier, statut: 'suivis'))

    expert_email = 'expert@tps.com'
    ask_confidential_avis(expert_email, 'a good introduction')

    ask_confidential_avis(instructeur2.email, 'a good introduction')

    click_on 'Personnes impliquées'
    expect(page).to have_current_path(personnes_impliquees_instructeur_dossier_path(procedure, dossier, statut: 'suivis'))
    expect(page).to have_text(expert_email)
    expect(page).to have_text(instructeur2.email)
  end

  scenario 'A instructeur can send a dossier to several instructeurs', chrome: true do
    instructeur_2 = create(:instructeur)
    instructeur_3 = create(:instructeur)
    procedure.defaut_groupe_instructeur.instructeurs << [instructeur_2, instructeur_3]

    send_dossier = double()
    expect(InstructeurMailer).to receive(:send_dossier).and_return(send_dossier).twice
    expect(send_dossier).to receive(:deliver_later).twice

    log_in(instructeur.email, password)

    click_on(procedure.libelle, visible: true)
    click_on dossier.user.email

    click_on 'Personnes impliquées'

    select_combobox('Emails', instructeur_2.email)
    select_combobox('Emails', instructeur_3.email)

    click_on 'Envoyer'

    expect(page).to have_text("Dossier envoyé")
  end

  scenario 'A instructeur can ask for an Archive' do
    archivable_procedure = create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }], instructeurs: [instructeur])
    create(:dossier, :accepte, procedure: archivable_procedure)

    log_in(instructeur.email, password)
    visit list_instructeur_archives_path(archivable_procedure)

    expect {
      page.first(".fr-table .fr-btn").click
      expect(page).to have_text("Votre demande a été prise en compte")
    }.to have_enqueued_job(ArchiveCreationJob).with(archivable_procedure, an_instance_of(Archive), instructeur)
    expect(Archive.first.month).not_to be_nil
  end

  context 'with dossiers having attached files' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }], instructeurs: [instructeur]) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let(:champ) { dossier.project_champs_public.first }
    let(:path) { 'spec/fixtures/files/piece_justificative_0.pdf' }
    let(:commentaire) { create(:commentaire, instructeur: instructeur, dossier: dossier) }

    before do
      dossier.passer_en_instruction!(instructeur: instructeur)
      champ.piece_justificative_file
        .attach(io: File.open(path),
                filename: "piece_justificative_0.pdf",
                content_type: "application/pdf",
                metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE })

      log_in(instructeur.email, password)
      visit instructeur_dossier_path(procedure, dossier)
    end

    scenario 'A instructeur can download an archive containing a single attachment' do
      find(:css, '[aria-controls=print-pj-menu]').click
      click_on 'Télécharger le dossier et toutes ses pièces jointes'

      DownloadHelpers.wait_for_download
      zip_path = DownloadHelpers.download
      expect(zip_path).to include "dossier-#{dossier.id}.zip"

      files = read_zip_entries(zip_path)
      expect(files.size).to be 2
      expect(files[0]).to include('export')
      expect(files[1]).to include('piece_justificative_0')

      content = read_zip_file_content(zip_path, files[1])
      expect(content.size).to eq(File.size(path))
    end

    scenario 'A instructeur can download an archive containing several identical attachments' do
      commentaire
        .piece_jointe
        .attach(io: File.open(path),
                filename: "piece_justificative_0.pdf",
                content_type: "application/pdf",
                metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE })

      find(:css, '[aria-controls=print-pj-menu]').click
      click_on 'Télécharger le dossier et toutes ses pièces jointes'

      DownloadHelpers.wait_for_download
      zip_path = DownloadHelpers.download
      expect(zip_path).to include "dossier-#{dossier.id}.zip"

      files = read_zip_entries(zip_path)
      expect(files.size).to be 3
      expect(files[0]).to include('export')
      expect(files[1]).to include('piece_justificative_0')
      expect(files[2]).to include('piece_justificative_0')
      expect(files[1]).not_to eq files[2]
      expect(read_zip_file_content(zip_path, files[1]).size).to be File.size(path)
      expect(read_zip_file_content(zip_path, files[2]).size).to be File.size(path)
    end

    before { DownloadHelpers.clear_downloads }
    after { DownloadHelpers.clear_downloads }
  end

  context 'An instructeur can add labels' do
    let(:procedure) { create(:procedure, :with_labels, :published, instructeurs: [instructeur]) }

    scenario 'An instructeur can add and remove labels to a dossier' do
      log_in(instructeur.email, password)

      visit instructeur_dossier_path(procedure, dossier)
      click_on 'Ajouter un label'

      check 'À relancer', allow_label_click: true
      expect(page).to have_css('.fr-tag', text: "À relancer", count: 2)
      expect(dossier.dossier_labels.count).to eq(1)

      expect(page).not_to have_text('Ajouter un label')
      find('span.dropdown button.dropdown-button').click

      expect(page).to have_checked_field('À relancer')
      check 'Complet', allow_label_click: true

      expect(page).to have_css('.fr-tag', text: "Complet", count: 2)
      expect(dossier.dossier_labels.count).to eq(2)

      find('span.dropdown button.dropdown-button').click
      uncheck 'À relancer', allow_label_click: true

      expect(page).to have_unchecked_field('À relancer')
      expect(page).to have_checked_field('Complet')
      expect(page).to have_css('.fr-tag', text: "À relancer", count: 1)
      expect(page).to have_css('.fr-tag', text: "Complet", count: 2)
      expect(dossier.dossier_labels.count).to eq(1)
    end
  end

  def log_in(email, password, check_email: false)
    visit new_user_session_path
    expect(page).to have_current_path(new_user_session_path)

    sign_in_with(email, password, check_email)

    expect(page).to have_current_path(instructeur_procedures_path)
  end

  def ask_confidential_avis(to, introduction)
    fill_in 'avis_emails', with: to
    fill_in 'avis_introduction', with: introduction
    choose 'confidentiel_true', allow_label_click: true
    within('form#new_avis') { click_on "Envoyer la demande d’avis" }
    click_on 'Demander un avis'
  end

  def test_statut_bar(a_suivre: 0, suivi: 0, traite: 0, tous_les_dossiers: 0, archive: 0)
    texts = [
      "#{a_suivre} à suivre",
      "#{suivi} suivis par moi",
      "#{traite} traités",
      "#{tous_les_dossiers} au total",
      "à archiver",
    ]

    texts.each { |text| expect(page).to have_text(text) }
  end

  def dossier_present?(id, statut)
    within(:css, '.dossiers-table') do
      expect(page).to have_text(id)
      expect(page).to have_text(statut)
    end
  end
end
