# frozen_string_literal: true

describe 'Signin in:' do
  let!(:user) { create(:user, password: password) }
  let(:password) { SECURE_PASSWORD }

  scenario 'an existing user can sign-in' do
    visit root_path
    click_on 'Se connecter', match: :first

    try_sign_in_with user.email, 'invalid-password'
    expect(page).to have_content 'Adresse électronique ou mot de passe incorrect.'
    expect(page).to have_field('Adresse électronique', with: user.email)

    sign_in_with user.email, password
    expect(page).to have_current_path dossiers_path
    expect(page).to have_content('Connecté(e).')
    expect(page).not_to have_content('Vous pouvez à tout moment alterner')
  end

  context 'user has multiple profiles' do
    let!(:instructeur) { create(:instructeur,    user: user) }
    let!(:admin)       { create(:administrateur, user: user, instructeur: instructeur) }

    scenario 'he can sign-in and he is notified in flash' do
      visit root_path
      click_on 'Se connecter', match: :first

      sign_in_with user.email, password
      expect(page).to have_current_path admin_procedures_path
      expect(page).to have_content('Vous êtes connecté(e) ! Vous pouvez à tout moment alterner entre vos différents profils : administrateur, instructeur et usager.')
    end
  end

  scenario 'an existing user can lock its account' do
    visit root_path
    click_on 'Se connecter', match: :first

    5.times { try_sign_in_with user.email, 'bad password' }
    expect(user.reload.access_locked?).to be false

    try_sign_in_with user.email, 'bad password'
    expect(user.reload.access_locked?).to be true
  end

  context 'when visiting a procedure' do
    let(:procedure) { create :simple_procedure, :with_service }

    before do
      visit commencer_path(path: procedure.path)
    end

    scenario 'an existing user can sign-in and fill the procedure' do
      click_on I18n.t('views.shared.account.already_user')
      expect(page).to have_current_path new_user_session_path

      sign_in_with user.email, password

      expect(page).to have_current_path(commencer_path(path: procedure.path))
      click_on 'Commencer la démarche'

      expect(page).to have_current_path identite_dossier_path(user.reload.dossiers.last)
      expect(page).to have_content(procedure.libelle)
      expect(page).to have_content "Votre identité"
    end
  end

  context 'when a user is not confirmed yet' do
    let!(:user) { create(:user, password: password, confirmed_at: nil) }

    # Ideally, when signing-in with an unconfirmed account,
    # the user would be redirected to the "resend email confirmation" page.
    #
    # However the check for unconfirmed accounts is made by Warden every time a page is loaded –
    # and much earlier than SessionsController#create.
    #
    # For now only test the default behavior (an error message is displayed).
    scenario 'they get an error message' do
      visit root_path
      click_on 'Se connecter', match: :first

      try_sign_in_with user.email, password
      expect(page).to have_content('Vous devez confirmer votre compte par email.')
    end
  end

  def try_sign_in_with(email, password)
    fill_in :user_email, with: email
    fill_in :user_password, with: password

    click_on 'Se connecter'
  end
end
