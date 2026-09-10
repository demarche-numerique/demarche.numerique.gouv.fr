# frozen_string_literal: true

describe 'Inviting an expert:', js: true do
  include ActiveJob::TestHelper
  include ActionView::Helpers

  let_it_be(:expert_password) { 'mot de passe d’expert' }
  let_it_be(:instructeur) { create(:instructeur, password: SECURE_PASSWORD) }
  let_it_be(:expert) { create(:expert, password: expert_password) }
  let_it_be(:expert2) { create(:expert, password: expert_password) }
  let_it_be(:expert3) { create(:expert, password: expert_password) }
  let_it_be(:expert4) { create(:expert, password: expert_password) }
  let_it_be(:procedure, reload: true) { create(:procedure, :published, instructeurs: [instructeur], public_type_de_champs: [{ type: :dossier_link }]) }
  let_it_be(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
  let_it_be(:linked_dossier) { Dossier.find_by(id: dossier.champ_data.first.value) }

  before do
    clear_emails
  end

  context 'as an Instructeur' do
    scenario 'I can invite experts, attach files, and paste email lists' do
      allow(ClamavService).to receive(:safe_file?).and_return(true)

      # assign instructeur to linked dossier
      instructeur.assign_to_procedure(linked_dossier.procedure)

      login_as instructeur.user, scope: :user
      visit instructeur_dossier_path(procedure, dossier)

      click_on 'Avis externes'
      expect(page).to have_current_path(avis_instructeur_dossier_path(procedure, dossier))
      within('.fr-sidemenu') { click_on 'Demander un avis' }
      expect(page).to have_current_path(avis_new_instructeur_dossier_path(procedure, dossier))

      # Invite multiple experts
      fill_in 'Emails', with: "#{expert3.email},#{expert4.email}"
      fill_in 'Emails', with: "#{expert.email},"
      fill_in 'Emails', with: expert2.email
      fill_in 'avis_introduction', with: 'Bonjour, merci de me donner votre avis sur ce dossier.'
      check 'avis_invite_linked_dossiers'
      choose 'confidentiel_true', allow_label_click: true

      within('form#new_avis') { click_on "Envoyer la demande d’avis" }
      perform_enqueued_jobs

      expect(page).to have_content('Une demande d’avis a été envoyée')
      expect(page).to have_content('Avis des experts')
      within('section') do
        expect(page).to have_content(expert.email.to_s)
        expect(page).to have_content(expert2.email.to_s)
        expect(page).to have_content(expert3.email.to_s)
        expect(page).to have_content(expert4.email.to_s)
        expect(page).to have_content('Bonjour, merci de me donner votre avis sur ce dossier.')
      end

      expect(Avis.where(dossier: [dossier, linked_dossier]).count).to eq(8)
      expect(emails_sent_to(expert.email.to_s).size).to eq(1)
      expect(emails_sent_to(expert2.email.to_s).size).to eq(1)
      invitation_email = open_email(expert.email.to_s)
      targeted_user_link = TargetedUserLink.joins(:user).where(user: { email: expert.email.to_s }).first
      targeted_user_url = targeted_user_link_url(targeted_user_link)
      expect(invitation_email.body).to include(targeted_user_url)

      # Invite with introduction file (reuse same login + navigation)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join('spec/fixtures/files/piece_justificative_0.pdf').open,
        filename: 'piece_justificative_0.pdf',
        content_type: 'application/pdf'
      )

      within('.fr-sidemenu') { click_on 'Demander un avis' }

      fill_in 'Emails', with: "expert-file@test.fr,"
      fill_in 'avis_introduction', with: 'Veuillez consulter le document ci-joint.'
      choose 'confidentiel_false', allow_label_click: true

      # Inject blob signed_id as hidden field to bypass direct upload
      page.execute_script(<<~JS)
        var form = document.querySelector('form#new_avis');
        var fileInput = form.querySelector('input[type="file"]');
        if (fileInput) fileInput.remove();
        var hidden = document.createElement('input');
        hidden.type = 'hidden';
        hidden.name = 'avis[introduction_file]';
        hidden.value = '#{blob.signed_id}';
        form.appendChild(hidden);
      JS

      within('form#new_avis') { click_on "Envoyer la demande d’avis" }
      perform_enqueued_jobs

      expect(page).to have_content("Une demande d’avis a été envoyée")
      expect(Avis.last.introduction_file).to be_attached

      # Paste a list of expert emails (reuse same login + navigation)
      within('.fr-sidemenu') { click_on 'Demander un avis' }

      fill_in 'Emails', with: "expert1@gouv.fr; expert2@gouv.fr; test@test.fr; email-invalide"
      fill_in 'avis_introduction', with: 'Bonjour, merci de me donner votre avis sur ce dossier.'
      check 'avis_invite_linked_dossiers'
      choose 'confidentiel_true', allow_label_click: true

      within('form#new_avis') { click_on "Envoyer la demande d’avis" }
      perform_enqueued_jobs

      expect(page).to have_content('Une demande d’avis a été envoyée')
      expect(page).to have_content('Demander un avis externe')
      expect(page).to have_content('Une demande d’avis a été envoyée à expert1@gouv.fr, expert2@gouv.fr, test@test.fr')
      expect(page).to have_content('email-invalide : Le champ « Adresse électronique » est invalide. Saisissez une adresse électronique valide.')
    end

    context 'when experts list is restricted by admin' do
      let!(:expert_procedure) { ExpertsProcedure.create(expert: expert, procedure: procedure, allow_decision_access: true) }

      before do
        procedure.update!(experts_require_administrateur_invitation: true)
      end

      scenario 'only allowed experts are invited' do
        allow(ClamavService).to receive(:safe_file?).and_return(true)

        # assign instructeur to linked dossier
        instructeur.assign_to_procedure(linked_dossier.procedure)

        login_as instructeur.user, scope: :user
        visit instructeur_dossier_path(procedure, dossier)

        click_on 'Avis externes'
        expect(page).to have_current_path(avis_instructeur_dossier_path(procedure, dossier))
        within('.fr-sidemenu') { click_on 'Demander un avis' }
        expect(page).to have_current_path(avis_new_instructeur_dossier_path(procedure, dossier))

        select_combobox :avis_emails, expert.email
        fill_in 'avis_introduction', with: 'Bonjour, merci de me donner votre avis sur ce dossier.'
        check 'avis_invite_linked_dossiers'
        choose 'confidentiel_true', allow_label_click: true

        within('form#new_avis') { click_on "Envoyer la demande d’avis" }
        perform_enqueued_jobs

        wait_until { expert_procedure.reload.avis.present? }

        expect(page).to have_content('Une demande d’avis a été envoyée')
        expect(page).to have_content('Avis des experts')
        within('section') do
          expect(page).to have_content(expert.email)
          expect(page).not_to have_content(expert2.email)
        end
      end
    end

    context 'when managing expert responses' do
      let(:experts_procedure) { create(:experts_procedure, expert:, procedure:) }
      let(:experts_procedure2) { create(:experts_procedure, expert: expert2, procedure:) }
      let!(:pending_avis) { create(:avis, dossier:, claimant: instructeur, experts_procedure:) }
      let!(:answered_avis) { create(:avis, :with_answer, dossier:, claimant: instructeur, experts_procedure: experts_procedure2) }

      scenario 'I can remind a pending expert and read an answered response' do
        login_as instructeur.user, scope: :user
        visit instructeur_dossier_path(procedure, dossier)

        click_on 'Avis externes'

        # Remind pending expert
        expect(page).to have_content(expert.email)
        accept_confirm("Souhaitez-vous relancer #{expert.email}") do
          click_on "Relancer l’expert"
        end

        expect(page).to have_content("Un mail de relance a été envoyé à #{expert.email}")
        expect(page).to have_content('Relance effectuée le')
        expect(pending_avis.reload.reminded_at).to be_present

        # Read answered expert's response
        expect(page).to have_content(expert2.email)
        answered_avis.answer.split("\n").map { |line| line.gsub("- ", "") }.map do |answer_line|
          expect(page).to have_content(answer_line)
        end
      end
    end
  end
end
