# frozen_string_literal: true

describe 'Editing a dossier as an instructeur:', js: true do
  include ActiveJob::TestHelper

  let(:password) { SECURE_PASSWORD }
  let!(:instructeur) { create(:instructeur, password: password) }

  def buffered_value(dossier, stable_id)
    dossier.reload.champ_data
      .find { _1.stream == Dossier::INSTRUCTEUR_BUFFER_STREAM && _1.stable_id == stable_id }
      &.value
  end

  # The merge moves the previous main champ to the history stream and promotes
  # the buffered champ as the new main one, so we must look it up by stream.
  def main_value(dossier, stable_id)
    dossier.reload.champ_data
      .find { _1.stream == Dossier::MAIN_STREAM && _1.stable_id == stable_id }
      &.value
  end

  let!(:procedure) do
    create(:procedure, :published,
      instructeurs: [instructeur],
      instructeurs_can_edit_dossiers: true,
      public_type_de_champs: [{ type: 'text', libelle: 'Texte', stable_id: 99 }])
  end

  context 'when the instructeur is not the owner of the dossier' do
    let!(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }

    before { login_as(instructeur.user, scope: :user) }

    scenario 'the instructeur can edit the dossier and the usager is notified' do
      visit instructeur_dossier_path(procedure, dossier, statut: 'a-suivre')

      click_on 'Modifier le dossier'

      expect(page).to have_content("Modifier le dossier n° #{dossier.id}")

      fill_in 'Texte', with: 'Valeur corrigée par l’instructeur'
      blur

      # changes are stored on a buffer stream, not yet on the dossier
      wait_until { buffered_value(dossier, 99) == 'Valeur corrigée par l’instructeur' }
      expect(main_value(dossier, 99)).not_to eq('Valeur corrigée par l’instructeur')

      # the submit button is enabled once the buffer holds changes
      click_on 'Enregistrer les modifications'

      # confirmation modal
      expect(page).to have_content("Modification du dossier n° #{dossier.id}")
      fill_in 'traitement_motivation', with: 'J’ai corrigé une coquille.'

      perform_enqueued_jobs do
        click_on 'Confirmer les modifications et notifier lʼusager'
      end

      expect(page).to have_current_path(instructeur_dossier_path(procedure, dossier, statut: 'a-suivre'))

      # the buffered change has been merged onto the dossier
      expect(main_value(dossier, 99)).to eq('Valeur corrigée par l’instructeur')

      # a traitement keeps track of who edited the dossier
      traitement = dossier.traitements.last
      expect(traitement.instructeur_email).to eq(instructeur.email)
      expect(traitement.motivation).to eq('J’ai corrigé une coquille.')

      # the usager is notified through the messagerie, with the detailed change and the motivation
      commentaire_body = dossier.commentaires.last.body
      expect(commentaire_body).to include('a apporté les modifications suivantes')
      expect(commentaire_body).to include('<dt>Texte :</dt>')
      expect(commentaire_body).to include('<strong>Valeur corrigée par l’instructeur</strong>')
      expect(commentaire_body).to include('J’ai corrigé une coquille.')
    end

    scenario 'the usager receives an email notification of the changes' do
      visit instructeur_dossier_path(procedure, dossier, statut: 'a-suivre')

      click_on 'Modifier le dossier'
      fill_in 'Texte', with: 'Valeur corrigée par l’instructeur'
      blur
      wait_until { buffered_value(dossier, 99) == 'Valeur corrigée par l’instructeur' }

      click_on 'Enregistrer les modifications'
      expect(page).to have_content("Modification du dossier n° #{dossier.id}")

      perform_enqueued_jobs do
        click_on 'Confirmer les modifications et notifier lʼusager'
        expect(page).to have_current_path(instructeur_dossier_path(procedure, dossier, statut: 'a-suivre'))
      end

      mail = ActionMailer::Base.deliveries.find { _1.to.to_a.include?(dossier.user.email) }
      expect(mail).to be_present
    end

    scenario 'the instructeur can cancel without saving' do
      visit instructeur_dossier_path(procedure, dossier, statut: 'a-suivre')
      click_on 'Modifier le dossier'

      fill_in 'Texte', with: 'Valeur jamais enregistrée'
      blur
      wait_until { buffered_value(dossier, 99) == 'Valeur jamais enregistrée' }

      # the footer cancel is a link, while the confirm modal (also inside the
      # footer) has an "Annuler" button — target the link to avoid ambiguity
      accept_confirm { within('.dossier-edit-footer') { click_link 'Annuler' } }

      expect(page).to have_current_path(instructeur_dossier_path(procedure, dossier, statut: 'a-suivre'))
      expect(main_value(dossier, 99)).not_to eq('Valeur jamais enregistrée')
    end
  end

  context 'when the dossier has a piece justificative champ' do
    let!(:procedure) do
      create(:procedure, :published,
        instructeurs: [instructeur],
        instructeurs_can_edit_dossiers: true,
        public_type_de_champs: [{ type: :piece_justificative, libelle: 'Justificatif', stable_id: 88 }])
    end
    let!(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }

    before { login_as(instructeur.user, scope: :user) }

    def buffered_pj(stable_id)
      dossier.reload.champ_data
        .find { _1.stream == Dossier::INSTRUCTEUR_BUFFER_STREAM && _1.stable_id == stable_id }
        &.piece_justificative_file
    end

    scenario 'the instructeur can remove and add a piece justificative' do
      visit instructeur_dossier_path(procedure, dossier, statut: 'a-suivre')
      click_on 'Modifier le dossier'

      expect(page).to have_content("Modifier le dossier n° #{dossier.id}")

      # removing the existing attachment is buffered on the instructeur stream,
      # and the instructeur footer reflects the buffered change
      find('button', text: 'Supprimer le fichier toto.txt').click
      expect(page).to have_no_button('Supprimer le fichier toto.txt')
      wait_until { buffered_pj(88)&.attachments&.empty? }
      expect(page).to have_button('Enregistrer les modifications', disabled: false)

      # adding a new attachment is buffered too
      input_selector = "##{dossier.root_champs_public.find { _1.stable_id == 88 }.focusable_input_id}"
      expect(page).to have_selector(input_selector)
      find(input_selector).attach_file(Rails.root.join('spec/fixtures/files/file.pdf'))

      wait_until { buffered_pj(88)&.attachments&.map { _1.filename.to_s } == ['file.pdf'] }
      expect(page).to have_text('file.pdf')
      expect(page).to have_button('Enregistrer les modifications', disabled: false)
    end
  end

  context 'when the edited dossier is invalid' do
    let!(:procedure) do
      create(:procedure, :published,
        instructeurs: [instructeur],
        instructeurs_can_edit_dossiers: true,
        public_type_de_champs: [{ type: 'text', libelle: 'Texte', stable_id: 99, mandatory: true }])
    end
    let!(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }

    before { login_as(instructeur.user, scope: :user) }

    scenario 'the errors are shown inline and the confirmation dialog stays closed' do
      visit instructeur_dossier_path(procedure, dossier, statut: 'a-suivre')
      click_on 'Modifier le dossier'

      # clearing a mandatory champ makes the dossier invalid
      fill_in 'Texte', with: ''
      blur

      # the submit button becomes enabled once the (now empty) change is buffered
      expect(page).to have_button('Enregistrer les modifications', disabled: false)

      click_on 'Enregistrer les modifications'

      # the validation errors surface inline, before any confirmation dialog
      expect(page).to have_content('Votre dossier contient 1 champ en erreur')
      # the confirmation dialog stays closed (DSFR sets [open] when disclosed)
      expect(page).to have_no_selector('#dossier-submit-dialog[open]', visible: :all)

      # fixing the champ then submitting opens the confirmation dialog
      fill_in 'Texte', with: 'Valeur corrigée par l’instructeur'
      blur
      wait_until { buffered_value(dossier, 99) == 'Valeur corrigée par l’instructeur' }

      click_on 'Enregistrer les modifications'
      expect(page).to have_selector('#dossier-submit-dialog[open]', visible: :all)
    end
  end

  context 'when the instructeur is also the owner of the dossier' do
    let!(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure, user: instructeur.user) }

    before { login_as(instructeur.user, scope: :user) }

    scenario 'the edit feature is not available' do
      visit instructeur_dossier_path(procedure, dossier, statut: 'a-suivre')

      expect(page).to have_content(procedure.libelle)
      expect(page).not_to have_link('Modifier le dossier')

      # even visiting the edit url directly redirects back to the dossier
      visit edit_instructeur_dossier_path(procedure, dossier, statut: 'a-suivre')
      expect(page).to have_current_path(instructeur_dossier_path(procedure, dossier, statut: 'a-suivre'))
    end
  end

  context 'when the procedure does not allow instructeurs to edit dossiers' do
    let!(:procedure) do
      create(:procedure, :published,
        instructeurs: [instructeur],
        instructeurs_can_edit_dossiers: false,
        public_type_de_champs: [{ type: 'text', libelle: 'Texte', stable_id: 99 }])
    end
    let!(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }

    before { login_as(instructeur.user, scope: :user) }

    scenario 'the edit feature is not available' do
      visit instructeur_dossier_path(procedure, dossier, statut: 'a-suivre')

      expect(page).to have_content(procedure.libelle)
      expect(page).not_to have_link('Modifier le dossier')

      # even visiting the edit url directly redirects back to the dossier
      visit edit_instructeur_dossier_path(procedure, dossier, statut: 'a-suivre')
      expect(page).to have_current_path(instructeur_dossier_path(procedure, dossier, statut: 'a-suivre'))
    end
  end
end
