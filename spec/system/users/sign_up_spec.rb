# frozen_string_literal: true

describe 'Signing up:', js: true do
  let(:user_email) { generate :user_email }
  let(:user_password) { SECURE_PASSWORD }
  let(:procedure) { procedures.individual }

  scenario 'a new user can sign-up from scratch' do
    visit new_user_registration_path

    sign_up_with user_email, user_password
    expect(page).to have_content "nous avons besoin de vérifier votre adresse électronique #{user_email}"
    expect(User.find_by(email: user_email).email_verified_at).to be_nil

    click_confirmation_link_for user_email
    expect(page).to have_content('Votre compte a bien été confirmé.')
    expect(User.find_by(email: user_email).email_verified_at).to be_present
    expect(page).to have_current_path dossiers_path
  end

  context 'when the user makes a typo in their email address' do
    let(:procedure) { procedures.individual }

    before do
      visit commencer_path(path: procedure.path)
      click_on "Créer un compte #{APPLICATION_NAME}"
      expect(page).to have_selector('.suspect-email', visible: false)
      fill_in 'Adresse électronique', with: 'bidou@yahoo.rf'
      fill_in 'Mot de passe', with: '1 2 3 4 5 6 '
    end

    scenario 'they can accept the suggestion', js: true do
      expect(page).to have_selector('.suspect-email', visible: true)
      click_on 'Oui'
      expect(page).to have_field("Adresse électronique", :with => 'bidou@yahoo.fr')
      expect(page).to have_selector('.suspect-email', visible: false)
    end

    scenario 'they can discard the suggestion', js: true do
      expect(page).to have_selector('.suspect-email', visible: true)
      click_on 'Non'
      expect(page).to have_field("Adresse électronique", :with => 'bidou@yahoo.rf')
      expect(page).to have_selector('.suspect-email', visible: false)
    end

    scenario 'they can fix the typo themselves', js: true do
      expect(page).to have_selector('.suspect-email', visible: true)
      fill_in 'Adresse électronique', with: 'bidou@yahoo.fr'
      blur
      expect(page).to have_selector('.suspect-email', visible: false)
    end
  end

  scenario 'a new user can’t sign-up with too short password when visiting a procedure' do
    visit commencer_path(path: procedure.path)
    click_on 'Créer un compte'

    expect(page).to have_current_path new_user_registration_path
    fill_in :user_email, with: user_email
    fill_in :user_password, with: '1234567'
    expect(page).to have_content "Le mot de passe doit faire au moins 12 caractères."

    # Then with a good password
    sign_up_with user_email, user_password
    expect(page).to have_current_path(/\/users\/confirmation\/new\?email=[^@]{32,}$/)
    expect(page).to have_content "nous avons besoin de vérifier votre adresse électronique #{user_email}"
  end

  context 'when visiting a procedure' do
    let(:procedure) { procedures.individual }

    scenario 'a new user can sign-up and fill the procedure' do
      visit commencer_path(path: procedure.path)

      click_on 'Créer un compte'
      expect(page).to have_current_path new_user_registration_path

      sign_up_with user_email, user_password
      expect(page).to have_content "nous avons besoin de vérifier votre adresse électronique #{user_email}"

      click_confirmation_link_for(user_email, in_another_browser: true)

      # After confirmation, the user is redirected to the procedure they were initially starting
      # (even when confirming the account in another browser).
      expect(page).to have_current_path(commencer_path(path: procedure.path))
      expect(page).to have_content I18n.t('devise.confirmations.confirmed')
      click_on 'Commencer un dossier'

      expect(page).to have_current_path identite_dossier_path(procedure.reload.dossiers.last)
      expect(page).to have_content(procedure.libelle)
    end
  end

  context 'when the user is not confirmed yet' do
    before do
      create(:user, :unconfirmed, email: user_email, password: user_password)
    end

    scenario 'the email confirmation page is displayed' do
      visit commencer_path(path: procedure.path)
      click_on 'Créer un compte'

      sign_up_with user_email, user_password

      # The same page than for initial sign-ups is displayed, to avoid leaking informations
      # about the account existence.
      expect(page).to have_content "nous avons besoin de vérifier votre adresse électronique #{user_email}"

      # The confirmation email is sent again
      confirmation_email = open_email(user_email)
      expect(confirmation_email.body).to have_text('Pour activer votre compte')

      click_confirmation_link_for(user_email, in_another_browser: true)

      # After confirmation, the user is redirected to the procedure they were initially starting
      # (even when confirming the account in another browser).
      expect(page).to have_current_path(commencer_path(path: procedure.path))
      expect(page).to have_content I18n.t('devise.confirmations.confirmed')
      expect(page).to have_content 'Commencer un dossier'
    end
  end

  context 'when the user already has a confirmed account' do
    before do
      create(:user, email: user_email, password: user_password)
    end

    scenario 'they get a warning email, containing a link to the procedure' do
      visit commencer_path(path: procedure.path)
      click_on 'Créer un compte'

      sign_up_with user_email, user_password

      # The same page than for initial sign-ups is displayed, to avoid leaking informations
      # about the accound existence.
      expect(page).to have_content "nous avons besoin de vérifier votre adresse électronique #{user_email}"

      # A warning email is sent
      warning_email = open_email(user_email)
      expect(warning_email.body).to have_text('Votre compte existe déjà')

      # When clicking the main button, the user is redirected directly to
      # the sign-in page for the procedure they were initially starting.
      click_procedure_sign_in_link_for user_email

      expect(page).to have_current_path new_user_session_path
    end
  end

  context 'when the user already has a confirmed account but is blocked' do
    before do
      create(:user, email: user_email, password: user_password, blocked_at: Time.current)
    end

    scenario 'they cannot signed in' do
      visit new_user_session_path
      fill_in :user_email, with: user_email
      fill_in :user_password, with: user_password

      click_on 'Se connecter'
      expect(page).to have_text "Votre compte n’est pas encore activé."

      expect(page).to have_current_path new_user_session_path
    end
  end
end
