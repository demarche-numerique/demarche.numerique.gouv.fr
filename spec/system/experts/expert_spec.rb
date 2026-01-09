# frozen_string_literal: true

describe 'Inviting an expert:', js: true do
  include ActiveJob::TestHelper
  include ActionView::Helpers
  include ZipHelpers

  context 'as an invited Expert' do
    let(:expert) { create(:expert) }
    let(:instructeur) { create(:instructeur) }
    let(:types_de_champ_private) { [] }
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }, { type: :dossier_link }], types_de_champ_private:, instructeurs: [instructeur]) }
    let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure:) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, :with_populated_annotations, procedure:) }
    let(:champ) { dossier.champs.first }
    let(:avis) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure, confidentiel: true) }
    let(:avis_with_question) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure, confidentiel: true, question_label: 'Question ?') }
    let(:dossier_accepte) { create(:dossier, :accepte, procedure:) }
    let(:avis_on_dossier_accepte) { create(:avis, dossier: dossier_accepte, claimant: instructeur, experts_procedure: experts_procedure, confidentiel: true) }

    context 'when I don’t already have an account' do
      let(:password) { 'This is an expert password' }

      before 'Signing up' do
        visit sign_up_expert_avis_path(avis.dossier.procedure, avis, email: avis.expert.email)

        expect(page).to have_field('Adresse électronique', with: avis.expert.email, disabled: true)
        fill_in 'Mot de passe', with: password
        click_on 'Créer un compte'
      end

      scenario 'I can see the avis after signing up' do
        expect(page).to have_current_path(expert_all_avis_path)
        expect(page).to have_text('1 avis à donner')
      end

      scenario 'I can sign-in again afterwards' do
        click_on(avis.expert.email.to_s, visible: true)
        click_on('Se déconnecter', visible: true)

        visit new_user_session_path
        sign_in_with avis.expert.email, password

        expect(page).to have_content('Vous pouvez à tout moment alterner entre vos différents profils : expert et usager.')
        expect(page).to have_current_path(expert_all_avis_path)
      end
    end

    context 'when I already have an existing account' do
      before do
        avis.expert.user.update!(last_sign_in_at: Time.zone.now)
        avis.expert.user.reload
      end
      scenario 'I can sign in' do
        visit sign_up_expert_avis_path(avis.dossier.procedure, avis, email: avis.expert.email)

        expect(page).to have_current_path(new_user_session_path)
        login_as avis.expert.user, scope: :user
        sign_in_with(avis.expert.email, '{My-$3cure-p4ssWord}')
        expect(page).to have_content("connecté en tant qu’expert")
        click_on(avis.expert.email.to_s, visible: true)
        click_on('Passer en usager', visible: true)
        expect(page).to have_current_path(dossiers_path)
      end
    end

    scenario 'I can give an answer' do
      avis # create avis
      avis_on_dossier_accepte # create avis
      login_as expert.user, scope: :user

      visit expert_all_avis_path
      expect(page).to have_text('1 avis à donner')
      expect(page).to have_text('0 avis donnés')

      expect(page).to have_selector('.fr-badge', text: 1)
      expect(page).to have_selector('.notifications')

      click_on '1 avis à donner'
      click_on avis.dossier.user.email
      within('.fr-tabs') { click_on 'Avis' }
      expect(page).to have_text("Demandeur : #{avis.claimant.email}")
      expect(page).to have_text('Cet avis est confidentiel')

      fill_in 'avis_answer', with: 'Ma réponse d’expert : c’est un oui.'
      find('.attachment input[name="avis[piece_justificative_file]"]').attach_file(Rails.root + 'spec/fixtures/files/RIB.pdf')
      click_on 'Envoyer votre avis'

      expect(page).to have_content('Votre réponse est enregistrée')
      expect(page).to have_content('Ma réponse d’expert : c’est un oui.')
      expect(page).to have_content('RIB.pdf')

      within('.fr-breadcrumb__list') { click_on 'Avis' }
      expect(page).to have_text('0 avis à donner')
      expect(page).to have_text('1 avis donné')

      expect(page).not_to have_selector('.fr-badge', text: 1)
      expect(page).not_to have_selector('.notifications')
    end

    scenario 'I can give a yes/no answer to a question' do
      avis_with_question # create avis
      login_as expert.user, scope: :user

      visit expert_all_avis_path
      expect(page).to have_text('1 avis à donner')
      expect(page).to have_text('0 avis donnés')

      click_on '1 avis à donner'
      click_on avis.dossier.user.email
      within('.fr-tabs') { click_on 'Avis' }
      expect(page).to have_text("Demandeur : #{avis.claimant.email}")
      expect(page).to have_text('Question ?')
      expect(page).to have_text('Cet avis est confidentiel')

      # check validation
      fill_in 'avis_answer', with: 'Ma réponse d’expert.'
      click_on 'Envoyer votre avis'
      expect(page).to have_content("Le champ « Réponse oui/non » n’est pas inclus(e) dans la liste")

      find('label', text: 'non').click
      fill_in 'avis_answer', with: 'Ma réponse d’expert.'
      click_on 'Envoyer votre avis'

      expect(page).to have_content('Votre réponse est enregistrée')
      expect(page).to have_content('Ma réponse d’expert.')
      expect(page).to have_content('non')

      click_on 'Voir les avis'
      expect(page).to have_text('Vous')
      expect(page).to have_text('non')

      within('.fr-breadcrumb__list') { click_on 'Avis' }
      expect(page).to have_text('1 avis donné')
    end

    # scenario 'I can invite other experts' do
    # end

    context 'with dossiers having attached files', js: true do
      let(:path) { 'spec/fixtures/files/piece_justificative_0.pdf' }
      let(:commentaire) { create(:commentaire, instructeur: instructeur, dossier: dossier) }
      let(:types_de_champ_private) { [{ type: :piece_justificative }] }

      scenario 'An Expert can download an archive containing attachments without any private champ, bill signature and operations logs' do
        avis # create avis
        login_as expert.user, scope: :user
        visit expert_all_avis_path

        click_on '1 avis à donner'
        click_on avis.dossier.user.email

        click_on 'Télécharger le dossier et toutes ses pièces jointes'

        DownloadHelpers.wait_for_download
        zip_path = DownloadHelpers.download
        expect(zip_path).to include "dossier-#{dossier.id}.zip"

        files = read_zip_entries(zip_path)
        expect(files.size).to be 2
        expect(files[0].include?('export')).to be_truthy
        expect(files[1].include?('toto')).to be_truthy

        content = read_zip_file_content(zip_path, files[1])
        expect(content.size).to eq(4)
      end

      before { DownloadHelpers.clear_downloads }
      after { DownloadHelpers.clear_downloads }
    end
  end

  context 'when there are two experts' do
    let(:expert_1) { create(:expert) }
    let(:expert_2) { create(:expert) }
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, :published, instructeurs: [instructeur], types_de_champ_public: [{ type: :dossier_link }]) }
    let(:experts_procedure_1) { create(:experts_procedure, expert: expert_1, procedure:) }
    let(:experts_procedure_2) { create(:experts_procedure, expert: expert_2, procedure:) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
    let!(:avis_1) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure_1, confidentiel: true) }
    let!(:avis_2) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure_2, confidentiel: false) }

    scenario 'As a expert_1, I can read expert_2 advice because it is not confidential' do
      login_as expert_1.user, scope: :user

      visit expert_all_avis_path
      expect(page).to have_text('1 avis à donner')
      expect(page).to have_text('0 avis donnés')

      click_on '1 avis à donner'
      click_on avis_1.dossier.user.email
      within('.fr-tabs') { click_on 'Avis' }
      expect(page).to have_text("Demandeur : #{avis_1.claimant.email}")
      click_on 'Voir les avis'
      expect(page).to have_text("Vous")
      expect(page).to have_text(avis_2.expert.email.to_s)
    end

    scenario 'As a expert_2, I cannot read expert_1 advice because it is confidential' do
      login_as expert_2.user, scope: :user

      visit expert_all_avis_path
      expect(page).to have_text('1 avis à donner')
      expect(page).to have_text('0 avis donnés')

      click_on '1 avis à donner'
      click_on avis_2.dossier.user.email
      within('.fr-tabs') { click_on 'Avis' }
      expect(page).to have_text("Demandeur : #{avis_2.claimant.email}")
      click_on 'Voir les avis'
      expect(page).to have_text("Vous")
      expect(page).not_to have_text(avis_1.expert.email.to_s)
    end
  end
end
