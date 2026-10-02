# frozen_string_literal: true

describe 'BatchOperation a dossier:', js: true do
  include ActionView::RecordIdentifier
  include ActiveJob::TestHelper

  let(:password) { 'demarches-simplifiees' }
  let(:instructeur) { create(:instructeur, password: password) }
  let(:procedure) { create(:simple_procedure, :published, instructeurs: [instructeur], administrateurs: [administrateurs.default]) }

  # A poll refreshing the page would consume the single render that shows the
  # finished alert and marks the batch as seen, so polls are answered with 204
  # unless a with_turbo_poll block asks for the real thing.
  before { suppress_turbo_poll }

  context 'with an instructeur' do
    scenario 'create a BatchOperation' do
      dossier_1 = create(:dossier, :accepte, procedure: procedure)
      dossier_2 = create(:dossier, :accepte, procedure: procedure)
      dossier_3 = create(:dossier, :accepte, procedure: procedure)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'traites')

      # check a11y with enabled checkbox
      expect(page).to be_axe_clean
      # ensure button is disabled by default
      expect(page).to have_button("Déplacer les dossiers dans “à archiver“", disabled: true)

      checkbox_id = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
      # batch one dossier
      check(checkbox_id)
      expect(page).to have_button("Déplacer les dossiers dans “à archiver“")

      # ensure batch is created

      open_dsfr_modal('#modal-archive-batch') { click_on "Déplacer les dossiers dans “à archiver“" }
      within('#modal-archive-batch') { click_on 'Confirmer' }

      # ensure batched dossier is disabled
      expect(page).to have_selector("##{checkbox_id}[disabled]")
      # ensure Batch is created
      expect(BatchOperation.count).to eq(1)
      # check a11y with disabled checkbox
      expect(page).to be_axe_clean

      # ensure alert is present
      expect(page).to have_content("Information : Une action de masse est en cours")
      expect(page).to have_content("1 dossier est en cours de déplacement dans « à archiver »")

      # ensure data-controller="turbo-poll" is present
      expect(page).to have_selector('[data-controller~="turbo-poll"]')

      # ensure jobs are queued
      perform_enqueued_jobs(only: [BatchOperationEnqueueAllJob])
      expect { perform_enqueued_jobs(only: [BatchOperationProcessOneJob]) }
        .to change { dossier_1.reload.archived }
        .from(false).to(true)

      # ensure alert updates when jobs are run: reloading renders the finished
      # alert and marks the batch as seen
      visit instructeur_procedure_path(procedure, statut: 'traites')
      expect(page).to have_content("L’action de masse est terminée")
      expect(page).to have_content("1 dossier a été placé dans « à archiver »")

      # ensure the next poll removes the seen alert, and turbo-poll with it
      with_turbo_poll do
        expect(page).not_to have_selector('[data-controller~="turbo-poll"]', wait: 10)
      end

      # clean alert after reload
      visit instructeur_procedure_path(procedure, statut: 'traites')
      expect(page).not_to have_content("L’action de masse est terminée")

      # try checkall
      find("##{dom_id(BatchOperation.new, :checkbox_all)}").check

      # multiple select notice don't appear if all the dossiers are on the same page
      expect(page).to have_selector('#js_batch_select_more', visible: false)

      [dossier_2, dossier_3].map do |dossier|
        dossier_checkbox_id = dom_id(BatchOperation.new, "checkbox_#{dossier.id}")
        expect(page).to have_selector("##{dossier_checkbox_id}:checked")
      end

      # submit checkall
      open_dsfr_modal('#modal-archive-batch') { click_on "Déplacer les dossiers dans “à archiver“" }
      within('#modal-archive-batch') { click_on 'Confirmer' }

      # reload
      visit instructeur_procedure_path(procedure, statut: 'traites')

      expect(BatchOperation.count).to eq(2)
      expect(BatchOperation.last.dossiers).to match_array([dossier_2, dossier_3])
    end

    scenario 'create a BatchOperation with more dossiers than pagination' do
      stub_const "Instructeurs::ProceduresController::ITEMS_PER_PAGE", 2
      dossier_1 = create(:dossier, :en_instruction, procedure: procedure)
      dossier_2 = create(:dossier, :en_instruction, procedure: procedure)
      dossier_3 = create(:dossier, :en_instruction, procedure: procedure)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'a-suivre')

      expect(page).to have_content("1 - 2 sur 3 dossiers")

      # click on check_all make the notice appear
      find("##{dom_id(BatchOperation.new, :checkbox_all)}").check
      expect(page).to have_selector('#js_batch_select_more')
      expect(page).to have_content('Les 2 dossiers de cette page sont sélectionnés. Sélectionner la totalité des 3 dossiers.')

      # click on selection link fill checkbox value with dossier_ids
      click_on("Sélectionner la totalité des 3 dossiers")
      expect(page).to have_content('3 dossiers sont sélectionnés. Effacer la sélection ')
      expect(find_field("batch_operation[dossier_ids][]", type: :hidden).value).to eq "#{dossier_3.id},#{dossier_2.id},#{dossier_1.id}"

      # click on delete link empty checkbox value and hide notice
      click_on("Effacer la sélection")
      expect(page).to have_selector('#js_batch_select_more', visible: false)
      expect(page).to have_button("Suivre les dossiers", disabled: true)
      expect(find_field("batch_operation[dossier_ids][]", type: :hidden).value).to eq ""

      # click on check_all + notice link and submit
      find("##{dom_id(BatchOperation.new, :checkbox_all)}").check
      click_on("Sélectionner la totalité des 3 dossiers")

      accept_alert do
        click_on "Suivre les dossiers"
      end

      # reload
      visit instructeur_procedure_path(procedure, statut: 'a-suivre')

      expect(BatchOperation.count).to eq(1)
      expect(BatchOperation.last.dossiers).to match_array([dossier_1, dossier_2, dossier_3])
    end

    scenario 'create a BatchOperation within the limit of selection' do
      stub_const "Instructeurs::ProceduresController::ITEMS_PER_PAGE", 2
      stub_const "BatchOperation::BATCH_SELECTION_LIMIT", 3
      dossier_1 = create(:dossier, :en_instruction, procedure: procedure)
      dossier_2 = create(:dossier, :en_instruction, procedure: procedure)
      dossier_3 = create(:dossier, :en_instruction, procedure: procedure)
      dossier_4 = create(:dossier, :en_instruction, procedure: procedure)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'a-suivre')

      # click on check_all make the notice appear
      find("##{dom_id(BatchOperation.new, :checkbox_all)}").check
      expect(page).to have_selector('#js_batch_select_more')
      expect(page).to have_content('Les 2 dossiers de cette page sont sélectionnés. Sélectionner les 3 premiers dossiers sur les 4')

      # click on selection link fill checkbox value with dossier_ids
      click_on("Sélectionner les 3 premiers dossiers sur les 4")
      expect(page).to have_content('3 dossiers sont sélectionnés. Effacer la sélection')
      expect(find_field("batch_operation[dossier_ids][]", type: :hidden).value).to eq "#{dossier_4.id},#{dossier_3.id},#{dossier_2.id}"

      # create batch
      accept_alert do
        click_on "Suivre les dossiers"
      end

      # reload
      visit instructeur_procedure_path(procedure, statut: 'a-suivre')

      expect(BatchOperation.count).to eq(1)
      expect(BatchOperation.last.dossiers).to match_array([dossier_2, dossier_3, dossier_4])
    end

    scenario 'create a BatchOperation for create_avis with modal' do
      dossier_1 = create(:dossier, :en_construction, procedure: procedure)
      dossier_2 = create(:dossier, :en_instruction, procedure: procedure)
      instructeur.follow(dossier_1)
      instructeur.follow(dossier_2)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'suivis')

      # check a11y with enabled checkbox
      expect(page).to be_axe_clean
      # ensure button is disabled by default
      expect(page).to have_button("Autres actions multiples", disabled: true)

      checkbox_id = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
      checkbox_id2 = dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")
      # batch one dossier
      check(checkbox_id)
      check(checkbox_id2)
      expect(page).to have_button("Autres actions multiples")

      open_dsfr_modal("#modal-avis-batch") do
        click_on "Autres actions multiples"
        click_on "Demander un avis externe"
      end

      scroll_to(find("#modal-avis-batch"))

      # can close the modal
      click_on "Annuler", visible: true
      expect(page).to have_selector("#modal-avis-batch", visible: false)

      # reopen the modal
      click_on "Autres actions multiples"
      click_on "Demander un avis externe"
      expect(page).to have_selector("#modal-avis-batch", visible: true)

      click_on "Envoyer la demande d’avis"

      expect(page).to have_content("Le champ « Adresse électronique » doit être rempli")

      # a separator commits each typed email as a chip
      fill_in('avis_emails', with: 'expert@example.com,mljkzmljz,')
      expect(page).to have_button('Supprimer expert@example.com')
      expect(page).to have_button('Supprimer mljkzmljz')

      click_on "Envoyer la demande d’avis"
      expect(page).to have_content("Le champ « Adresse électronique » est invalide : mljkzmljz")

      # the 422 re-renders the form without the submitted emails: the chips
      # only survive because the stream morphs the form
      expect(page).to have_button('Supprimer expert@example.com')
      expect(page).to have_button('Supprimer mljkzmljz')

      # fix the error without typing the valid email again
      click_on 'Supprimer mljkzmljz'
      expect(page).not_to have_button('Supprimer mljkzmljz')

      within('form#new_avis') { click_on "Annuler" }

      expect(page).not_to have_content("Information : Une action de masse est en cours")

      click_on "Autres actions multiples"
      click_on "Demander un avis externe"

      expect(page).to have_button('Supprimer expert@example.com')
      click_on "Envoyer la demande d’avis"
      # ensure batched dossier is disabled
      expect(page).to have_selector("##{checkbox_id}[disabled]")
      expect(page).to have_selector("##{checkbox_id2}[disabled]")
      # ensure Batch is created
      expect(BatchOperation.count).to eq(1)
      expect(BatchOperation.last.emails).to eq(['expert@example.com'])
      # check a11y with disabled checkbox
      expect(page).to be_axe_clean

      # ensure alert is present
      expect(page).to have_content("Information : Une action de masse est en cours")
      expect(page).to have_content("Des demandes d’avis sont en cours d’envoi pour 0/2 dossiers")

      # ensure data-controller="turbo-poll" is present
      expect(page).to have_selector('[data-controller~="turbo-poll"]')

      # ensure jobs are queued
      perform_enqueued_jobs(only: [BatchOperationEnqueueAllJob])

      expect {
        perform_enqueued_jobs(only: [BatchOperationProcessOneJob])
      }.to change { dossier_1.reload.avis.count }.by(1)

      # ensure alert updates when jobs are run: reloading renders the finished
      # alert and marks the batch as seen
      visit instructeur_procedure_path(procedure, statut: 'suivis')
      expect(page).to have_content("L’action de masse est terminée")
      expect(page).to have_content("Des demandes d’avis ont été envoyées pour 2/2 dossiers")

      # ensure the next poll removes the seen alert, and turbo-poll with it
      with_turbo_poll do
        expect(page).not_to have_selector('[data-controller~="turbo-poll"]', wait: 10)
      end

      # clean alert after reload
      visit instructeur_procedure_path(procedure, statut: 'suivis')
      expect(page).not_to have_content("L’action de masse est terminée")

      expect {
        perform_enqueued_jobs(only: [BatchOperationProcessOneJob])
      }.to change { dossier_1.reload.avis.count }.by(0)

      expect(PriorizedMailDeliveryJob).to have_been_enqueued.once.with(
        "AvisMailer",
        "avis_invitation_and_confirm_email",
        "deliver_now",
        anything
      )
    end

    scenario 'create a BatchOperation for create_commentaire with modal in Suivis tab' do
      dossier_1 = create(:dossier, :en_construction, procedure: procedure)
      dossier_2 = create(:dossier, :en_instruction, procedure: procedure)
      instructeur.follow(dossier_1)
      instructeur.follow(dossier_2)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'suivis')

      checkbox_id_1 = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
      checkbox_id_2 = dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")

      # batch two dossiers
      check(checkbox_id_1)
      check(checkbox_id_2)
      expect(page).to have_button("Autres actions multiples")

      open_dsfr_modal("#modal-commentaire-batch") do
        click_on "Autres actions multiples"
        click_on "Envoyer un message aux usagers"
      end

      scroll_to(find("#modal-commentaire-batch"))

      # can close the modal
      click_on "Annuler", visible: true
      expect(page).to have_selector("#modal-commentaire-batch", visible: false)

      # reopen the modal
      open_dsfr_modal("#modal-commentaire-batch") do
        click_on "Autres actions multiples"
        click_on "Envoyer un message aux usagers"
      end

      click_on "Envoyer le message"

      expect(page).to have_content("Envoyer un message à 2 usagers")
      fill_in('Votre message', with: "Bonjour,\r\nÊtes-vous disponible pour un rendez-vous en visio la semaine prochaine ?\r\nCordialement")
      click_on "Envoyer le message"

      # ensure batched dossiers are disabled
      expect(page).to have_selector("##{checkbox_id_1}[disabled]")
      expect(page).to have_selector("##{checkbox_id_2}[disabled]")
      # ensure Batch is created
      expect(BatchOperation.count).to eq(1)
      # check a11y with disabled checkbox
      expect(page).to be_axe_clean

      # ensure alert is present
      expect(page).to have_content("Information : Une action de masse est en cours")
      expect(page).to have_content("Un message est en cours d’envoi pour 0/2 dossiers")

      # ensure data-controller="turbo-poll" is present
      expect(page).to have_selector('[data-controller~="turbo-poll"]')

      # ensure jobs are queued
      perform_enqueued_jobs(only: [BatchOperationEnqueueAllJob])
      expect { perform_enqueued_jobs(only: [BatchOperationProcessOneJob]) }
        .to change { dossier_1.reload.commentaires }
        .from([]).to(anything)

      # ensure alert updates when jobs are run: reloading renders the finished
      # alert and marks the batch as seen
      visit instructeur_procedure_path(procedure, statut: 'suivis')
      expect(page).to have_content("L’action de masse est terminée")
      expect(page).to have_content("Un message a été envoyé pour 2/2 dossiers")

      # ensure the next poll removes the seen alert, and turbo-poll with it
      with_turbo_poll do
        expect(page).not_to have_selector('[data-controller~="turbo-poll"]', wait: 10)
      end

      # clean alert after reload
      visit instructeur_procedure_path(procedure, statut: 'suivis')
      expect(page).not_to have_content("L'action de masse est terminée")
    end

    scenario 'create a BatchOperation for create_commentaire with piece jointe' do
      dossier_1 = create(:dossier, :en_construction, procedure: procedure)
      instructeur.follow(dossier_1)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'suivis')

      checkbox_id_1 = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
      check(checkbox_id_1)

      open_dsfr_modal("#modal-commentaire-batch") do
        click_on "Autres actions multiples"
        click_on "Envoyer un message aux usagers"
      end

      fill_in('Votre message', with: 'Veuillez trouver ci-joint le document')

      within('#modal-commentaire-batch') do
        find('input[type="file"]', visible: false).attach_file(Rails.root.join('spec/fixtures/files/piece_justificative_0.pdf'))
      end

      # another batch takes the dossier while the message is being written: the
      # stream re-renders the form, and the typed body and the selected file
      # must survive it
      competing_batch = create(:batch_operation, operation: :passer_en_instruction, instructeur:, dossiers: [dossier_1])
      click_on "Envoyer le message"

      within('#modal-commentaire-batch') do
        expect(page).to have_content('piece_justificative_0.pdf')
        expect(page).to have_field('Votre message', with: 'Veuillez trouver ci-joint le document')
      end

      competing_batch.destroy!
      click_on "Envoyer le message"

      expect(page).to have_selector("##{checkbox_id_1}[disabled]")
      expect(BatchOperation.count).to eq(1)

      perform_enqueued_jobs(only: [BatchOperationEnqueueAllJob])
      perform_enqueued_jobs(only: [BatchOperationProcessOneJob])

      expect(dossier_1.reload.commentaires.last.body).to eq('Veuillez trouver ci-joint le document')
      expect(dossier_1.commentaires.last.piece_jointe).to be_attached
    end

    scenario 'create a BatchOperation for create_commentaire without modal in À suivre tab' do
      dossier_1 = create(:dossier, :en_construction, procedure: procedure)
      dossier_2 = create(:dossier, :en_construction, procedure: procedure)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'a-suivre')

      checkbox_id_1 = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
      checkbox_id_2 = dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")

      # batch two dossiers
      check(checkbox_id_1)
      check(checkbox_id_2)

      open_dsfr_modal("#modal-commentaire-batch") { click_on "Envoyer un message aux usagers" }

      expect(page).to have_content("Envoyer un message à 2 usagers")
      fill_in('Votre message', with: "Bonjour,\r\nÊtes-vous disponible pour un rendez-vous en visio la semaine prochaine ?\r\nCordialement")
      click_on "Envoyer le message"

      # ensure batched dossiers are disabled
      expect(page).to have_selector("##{checkbox_id_1}[disabled]")
      expect(page).to have_selector("##{checkbox_id_2}[disabled]")
      # ensure Batch is created
      expect(BatchOperation.count).to eq(1)
      expect(BatchOperation.last.operation).to eq('create_commentaire')
    end

    scenario 'create a BatchOperation for create_commentaire without modal in Traités tab' do
      dossier_1 = create(:dossier, :accepte, procedure: procedure)
      dossier_2 = create(:dossier, :accepte, procedure: procedure)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'traites')

      checkbox_id_1 = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
      checkbox_id_2 = dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")

      # batch two dossiers
      check(checkbox_id_1)
      check(checkbox_id_2)
      expect(page).to have_button("Envoyer un message aux usagers")

      open_dsfr_modal("#modal-commentaire-batch") { click_on "Envoyer un message aux usagers" }

      expect(page).to have_content("Envoyer un message à 2 usagers")
      fill_in('Votre message', with: "Bonjour,\r\nÊtes-vous disponible pour un rendez-vous en visio la semaine prochaine ?\r\nCordialement")
      click_on "Envoyer le message"

      # ensure batched dossiers are disabled
      expect(page).to have_selector("##{checkbox_id_1}[disabled]")
      expect(page).to have_selector("##{checkbox_id_2}[disabled]")
      # ensure Batch is created
      expect(BatchOperation.count).to eq(1)
      expect(BatchOperation.last.operation).to eq('create_commentaire')
    end

    scenario 'create a BatchOperation for create_commentaire without modal in Tous tab' do
      dossier_1 = create(:dossier, :en_construction, procedure: procedure)
      dossier_2 = create(:dossier, :accepte, procedure: procedure)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'tous')

      checkbox_id_1 = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
      checkbox_id_2 = dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")

      # batch two dossiers
      check(checkbox_id_1)
      check(checkbox_id_2)
      expect(page).to have_button("Envoyer un message aux usagers")

      open_dsfr_modal("#modal-commentaire-batch") { click_on "Envoyer un message aux usagers" }

      scroll_to(find("#modal-commentaire-batch"))

      expect(page).to have_content("Envoyer un message à 2 usagers")
      fill_in('Votre message', with: "Message de test pour l’onglet tous")
      click_on "Envoyer le message"

      # ensure batched dossiers are disabled
      expect(page).to have_selector("##{checkbox_id_1}[disabled]")
      expect(page).to have_selector("##{checkbox_id_2}[disabled]")
      # ensure Batch is created
      expect(BatchOperation.count).to eq(1)
      expect(BatchOperation.last.operation).to eq('create_commentaire')
    end
  end

  scenario 'create a BatchOperation for instruction with modal' do
    dossier_1 = create(:dossier, :en_instruction, procedure: procedure)
    dossier_2 = create(:dossier, :en_instruction, procedure: procedure)
    instructeur.follow(dossier_1)
    instructeur.follow(dossier_2)
    log_in(instructeur.email, password)

    visit instructeur_procedure_path(procedure, statut: 'suivis')

    checkbox_id_1 = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
    checkbox_id_2 = dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")

    expect(page).to have_button("Rendre une décision", disabled: true)

    check(checkbox_id_1)
    check(checkbox_id_2)

    expect(page).to have_button("Rendre une décision")

    open_dsfr_modal("#modal-instruction-button") { click_on "Rendre une décision" }

    scroll_to(find("#modal-instruction-button"))

    expect(page).to have_content("Rendre une décision sur les dossiers")
    expect(page).to have_content("Accepter les dossiers")
    expect(page).to have_content("Refuser les dossiers")
    expect(page).to have_content("Classer sans suite les dossiers")

    # on peut fermer la modale
    click_on "Fermer", visible: true
    expect(page).to have_selector("#modal-instruction-button", visible: false)

    # on la rouvre
    open_dsfr_modal("#modal-instruction-button") { click_on "Rendre une décision" }

    # on sélectionne une tuile puis on fait retour
    click_on "Accepter les dossiers"
    expect(page).to have_field("motivation_accept")

    click_on "Retour"
    expect(page).to have_content("Accepter les dossiers")
    expect(page).to have_content("Refuser les dossiers")

    # puis on continue avec l'acceptation comme avant
    click_on "Accepter les dossiers"

    expect(page).to have_field("motivation_accept")
    fill_in("motivation_accept", with: "Motivation batch d’acceptation")

    accept_alert do
      click_on "Valider la décision"
    end

    expect(page).to have_selector("##{checkbox_id_1}[disabled]")
    expect(page).to have_selector("##{checkbox_id_2}[disabled]")

    expect(BatchOperation.count).to eq(1)
    expect(BatchOperation.last.operation).to eq("accepter")
    expect(BatchOperation.last.dossiers).to match_array([dossier_1, dossier_2])

    expect(page).to be_axe_clean
    expect(page).to have_content("Information : Une action de masse est en cours")
    expect(page).to have_selector('[data-controller~="turbo-poll"]')
  end

  scenario 'create a BatchOperation for refusal with modal and justificatif' do
    dossier_1 = create(:dossier, :en_instruction, :with_individual, procedure: procedure)
    dossier_2 = create(:dossier, :en_instruction, :with_individual, procedure: procedure)
    instructeur.follow(dossier_1)
    instructeur.follow(dossier_2)
    log_in(instructeur.email, password)

    visit instructeur_procedure_path(procedure, statut: 'suivis')

    checkbox_id_1 = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
    checkbox_id_2 = dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")

    check(checkbox_id_1)
    check(checkbox_id_2)

    open_dsfr_modal("#modal-instruction-button") { click_on "Rendre une décision" }

    click_on "Refuser les dossiers"

    expect(page).to have_field("motivation_refuse")

    # le confirm se déclenche avant la validation (statu quo produit),
    # puis la validation cliente bloque la soumission vide.
    # On stub window.confirm : deux confirms successifs sur le même bouton
    # (validation bloquante puis soumission avec pièce jointe) ne sont pas
    # gérés de façon fiable par les vraies boîtes de dialogue.
    page.execute_script('window.confirm = () => true')
    click_on "Valider la décision"

    expect(page).to have_css(".fr-input-group--error")
    expect(page).to have_css('#motivation_refuse-error:not(.hidden)', text: "« Motivation » doit être rempli")
    expect(BatchOperation.count).to eq(0)

    fill_in("motivation_refuse", with: "Refus batch avec justificatif")
    expect(page).to have_no_css(".fr-input-group--error")

    within(".motivation.refuse") do
      find('input[type="file"]', visible: :all).attach_file(
        Rails.root.join("spec/fixtures/files/piece_justificative_0.pdf")
      )
    end

    page.execute_script('window.confirm = () => true')
    click_on "Valider la décision"

    expect(page).to have_selector("##{checkbox_id_1}[disabled]")
    expect(page).to have_selector("##{checkbox_id_2}[disabled]")

    expect(BatchOperation.count).to eq(1)
    expect(BatchOperation.last.operation).to eq("refuser")
    expect(BatchOperation.last.dossiers).to match_array([dossier_1, dossier_2])

    perform_enqueued_jobs(only: [BatchOperationEnqueueAllJob])
    perform_enqueued_jobs(only: [BatchOperationProcessOneJob])

    expect(dossier_1.reload).to be_refuse
    expect(dossier_2.reload).to be_refuse
    expect(dossier_1.justificatif_motivation).to be_attached
  end

  def log_in(email, password)
    visit new_user_session_path
    expect(page).to have_current_path(new_user_session_path)

    sign_in_with(email, password)

    expect(page).to have_current_path(instructeur_procedures_path)
  end
end
