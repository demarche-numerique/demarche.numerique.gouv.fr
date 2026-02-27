# frozen_string_literal: true

describe 'As an instructeur', js: true do
  let(:administrateur) { create(:administrateur, :with_procedure) }
  let(:procedure) { administrateur.procedures.first }
  let(:instructeur_email) { 'new_instructeur@gouv.fr' }

  before do
    login_as administrateur.user, scope: :user

    visit admin_procedure_path(procedure)
    find('#groupe-instructeurs').click

    select_combobox('Emails', instructeur_email, custom_value: true)

    perform_enqueued_jobs { click_on 'Ajouter' }

    expect(page).to have_text("Les instructeurs ont bien été affectés à la démarche")
  end

  scenario 'I can register' do
    confirmation_email = emails_sent_to(instructeur_email).first
    token_params = confirmation_email.body.match(/token=[^"]+/)

    visit "users/activate?#{token_params}"
    fill_in :user_password, with: SECURE_PASSWORD

    click_button 'Créer un compte'

    expect(page).to have_content 'Mot de passe enregistré'
  end
end
