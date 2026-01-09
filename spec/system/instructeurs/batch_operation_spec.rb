# frozen_string_literal: true

describe 'BatchOperation a dossier:', js: true do
  include ActionView::RecordIdentifier
  include ActiveJob::TestHelper

  let(:password) { 'demarches-simplifiees' }
  let(:instructeur) { create(:instructeur, password: password) }
  let(:procedure) { create(:simple_procedure, :published, instructeurs: [instructeur], administrateurs: [administrateurs(:default_admin)]) }

  context 'with an instructeur' do
    scenario 'create a BatchOperation', chrome: true do
      dossier_1 = create(:dossier, :accepte, procedure: procedure)
      dossier_2 = create(:dossier, :accepte, procedure: procedure)
      dossier_3 = create(:dossier, :accepte, procedure: procedure)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'traites')

      # check a11y with enabled checkbox
      expect(page).to be_axe_clean
      # ensure button is disabled by default
      expect(page).to have_button("Archiver les dossiers", disabled: true)

      checkbox_id = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
      # batch one dossier
      check(checkbox_id)
      expect(page).to have_button("Archiver les dossiers")

      # ensure batch is created

      accept_alert do
        click_on "Archiver les dossiers"
      end

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

      scroll_to(find_button("Personnaliser le tableau"))

      # ensure alert updates when jobs are run
      expect(page).to have_content("L’action de masse est terminée")
      expect(page).to have_content("1 dossier a été placé dans « à archiver »")

      # ensure data-controller="turbo-poll" is no longer present
      expect(page).not_to have_selector('[data-controller~="turbo-poll"]')

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
      accept_alert do
        click_on "Archiver les dossiers"
      end

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

    scenario 'create a BatchOperation for create_avis with modal', chrome: true do
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
      # batch one dossier
      check(checkbox_id)
      expect(page).to have_button("Autres actions multiples")

      click_on "Autres actions multiples"
      click_on "Demander un avis externe"

      scroll_to(find("#modal-avis-batch"))

      # can close the modal
      expect(page).to have_selector("#modal-avis-batch", visible: true)
      click_on "Annuler", visible: true
      expect(page).to have_selector("#modal-avis-batch", visible: false)

      # reopen the modal
      click_on "Autres actions multiples"
      click_on "Demander un avis externe"
      expect(page).to have_selector("#modal-avis-batch", visible: true)

      click_on "Envoyer la demande d’avis"

      expect(page).to have_content("Le champ « Email » doit être rempli")

      fill_in('avis_emails', with: 'mljkzmljz')
      click_on "Envoyer la demande d’avis"
      expect(page).to have_content("Le champ « Email » est invalide : mljkzmljz")

      fill_in('avis_emails', with: 'test@test.com')
      within('form#new_avis') { click_on "Annuler" }

      expect(page).not_to have_content("Information : Une action de masse est en cours")

      click_on "Autres actions multiples"
      click_on "Demander un avis externe"

      fill_in('avis_emails', with: 'test@test.com')
      click_on "Envoyer la demande d’avis"
      # ensure batched dossier is disabled
      expect(page).to have_selector("##{checkbox_id}[disabled]")
      # ensure Batch is created
      expect(BatchOperation.count).to eq(1)
      # check a11y with disabled checkbox
      expect(page).to be_axe_clean

      # ensure alert is present
      expect(page).to have_content("Information : Une action de masse est en cours")
      expect(page).to have_content("Une demande d’avis est en cours d’envoi pour 1 dossier")

      # ensure data-controller="turbo-poll" is present
      expect(page).to have_selector('[data-controller~="turbo-poll"]')

      # ensure jobs are queued
      perform_enqueued_jobs(only: [BatchOperationEnqueueAllJob])
      expect { perform_enqueued_jobs(only: [BatchOperationProcessOneJob]) }
        .to change { dossier_1.reload.avis }
        .from([]).to(anything)

      scroll_to(find_button("Personnaliser le tableau"))

      # ensure alert updates when jobs are run
      expect(page).to have_content("L’action de masse est terminée")
      expect(page).to have_content("Une demande d’avis a été envoyée pour 1 dossier")

      # ensure data-controller="turbo-poll" is no longer present
      expect(page).not_to have_selector('[data-controller~="turbo-poll"]')

      # clean alert after reload
      visit instructeur_procedure_path(procedure, statut: 'suivis')
      expect(page).not_to have_content("L’action de masse est terminée")
    end

    scenario 'create a BatchOperation for create_commentaire with modal in Suivis tab', chrome: true do
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

      click_on "Autres actions multiples"
      click_on "Envoyer un message aux usagers"

      scroll_to(find("#modal-commentaire-batch"))

      # can close the modal
      expect(page).to have_selector("#modal-commentaire-batch", visible: true)
      click_on "Annuler", visible: true
      expect(page).to have_selector("#modal-commentaire-batch", visible: false)

      # reopen the modal
      click_on "Autres actions multiples"
      click_on "Envoyer un message aux usagers"
      expect(page).to have_selector("#modal-commentaire-batch", visible: true)

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

      scroll_to(find(".batch-alert-component"))

      # ensure alert updates when jobs are run
      expect(page).to have_content("L’action de masse est terminée")
      expect(page).to have_content("Un message a été envoyé pour 2/2 dossiers")

      # ensure data-controller="turbo-poll" is no longer present
      expect(page).not_to have_selector('[data-controller~="turbo-poll"]')

      # clean alert after reload
      visit instructeur_procedure_path(procedure, statut: 'suivis')
      expect(page).not_to have_content("L’action de masse est terminée")
    end

    scenario 'create a BatchOperation for create_commentaire without modal in À suivre tab', chrome: true do
      dossier_1 = create(:dossier, :en_construction, procedure: procedure)
      dossier_2 = create(:dossier, :en_construction, procedure: procedure)
      log_in(instructeur.email, password)

      visit instructeur_procedure_path(procedure, statut: 'a-suivre')

      checkbox_id_1 = dom_id(BatchOperation.new, "checkbox_#{dossier_1.id}")
      checkbox_id_2 = dom_id(BatchOperation.new, "checkbox_#{dossier_2.id}")

      # batch two dossiers
      check(checkbox_id_1)
      check(checkbox_id_2)

      click_on "Envoyer un message aux usagers"

      expect(page).to have_selector("#modal-commentaire-batch", visible: true)
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

    scenario 'create a BatchOperation for create_commentaire without modal in Traités tab', chrome: true do
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

      click_on "Envoyer un message aux usagers"

      expect(page).to have_selector("#modal-commentaire-batch", visible: true)
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

    scenario 'create a BatchOperation for create_commentaire without modal in Tous tab', chrome: true do
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

      click_on "Envoyer un message aux usagers"

      scroll_to(find("#modal-commentaire-batch"))

      expect(page).to have_selector("#modal-commentaire-batch", visible: true)
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

  def log_in(email, password)
    visit new_user_session_path
    expect(page).to have_current_path(new_user_session_path)

    sign_in_with(email, password)

    expect(page).to have_current_path(instructeur_procedures_path)
  end
end
