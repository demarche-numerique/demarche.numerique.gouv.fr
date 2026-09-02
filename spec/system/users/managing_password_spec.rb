# frozen_string_literal: true

describe 'Managing password:', js: true do
  context 'for simple users' do
    let(:user) { create(:user) }
    let(:new_password) { 'a new, long, and complicated password!' }

    scenario 'a simple user can reset their password' do
      visit root_path
      within('.fr-header .fr-container .fr-header__tools .fr-btns-group') do
        click_on 'Se connecter'
      end
      click_on 'Mot de passe oublié ?'
      expect(page).to have_current_path(new_user_password_path)

      fill_in 'Adresse électronique', with: user.email
      perform_enqueued_jobs do
        click_on 'Demander un nouveau mot de passe'
      end
      expect(page).to have_text 'nous vous avons envoyé un email'
      expect(page).to have_text user.email

      click_reset_password_link_for user.email
      expect(page).to have_content 'Changement de mot de passe'

      fill_in 'user_password', with: new_password
      fill_in 'user_password_confirmation', with: new_password
      click_on 'Changer le mot de passe'
      expect(page).to have_content('Votre mot de passe a bien été modifié.')
    end
  end

  context 'for admins' do
    let(:administrateur) { administrateurs.default }
    let(:user) { administrateur.user }
    let(:weak_password) { '000000000000' }
    let(:strong_password) { 'a new, long, and complicated password!' }

    scenario 'an admin can reset their password' do
      visit root_path
      within('.fr-header .fr-container .fr-header__tools .fr-btns-group') do
        click_on 'Se connecter'
      end
      click_on 'Mot de passe oublié ?'
      expect(page).to have_current_path(new_user_password_path)

      fill_in 'Adresse électronique', with: user.email
      perform_enqueued_jobs do
        click_on 'Demander un nouveau mot de passe'
      end
      expect(page).to have_text 'nous vous avons envoyé un email'
      expect(page).to have_text user.email

      click_reset_password_link_for user.email

      expect(page).to have_content 'Changement de mot de passe'

      fill_in 'user_password', with: weak_password
      fill_in 'user_password_confirmation', with: weak_password
      expect(page).to have_text('Mot de passe très vulnérable')
      expect(page).to have_button('Changer le mot de passe', disabled: true)

      fill_in 'user_password', with: strong_password
      fill_in 'user_password_confirmation', with: strong_password
      expect(page).to have_text('Mot de passe suffisamment fort et sécurisé')
      expect(page).to have_button('Changer le mot de passe', disabled: false)

      click_on 'Changer le mot de passe'
      expect(page).to have_content('Votre mot de passe a bien été modifié.')
    end
  end

  context 'for super-admins' do
    let(:super_admin) { create(:super_admin) }
    let(:weak_password) { '000000000000' }
    let(:strong_password) { 'a new, long, and complicated password!' }

    scenario 'a super-admin can reset their password' do
      visit manager_root_path
      click_on 'Mot de passe oublié'
      expect(page).to have_current_path(new_super_admin_password_path)

      fill_in 'Adresse électronique', with: super_admin.email
      perform_enqueued_jobs do
        click_on 'Demander un nouveau mot de passe'
      end
      expect(page).to have_text 'vous recevrez un lien vous permettant de récupérer votre mot de passe'

      click_reset_password_link_for super_admin.email

      expect(page).to have_content 'Changement de mot de passe'

      fill_in 'super_admin_password', with: weak_password
      fill_in 'super_admin_password_confirmation', with: weak_password
      expect(page).to have_text('Mot de passe très vulnérable')
      expect(page).to have_button('Changer le mot de passe', disabled: true)

      fill_in 'super_admin_password', with: strong_password
      fill_in 'super_admin_password_confirmation', with: strong_password
      expect(page).to have_text('Mot de passe suffisamment fort et sécurisé')
      expect(page).to have_button('Changer le mot de passe', disabled: false)

      click_on 'Changer le mot de passe'
      expect(page).to have_content('Votre mot de passe a bien été modifié.')
    end
  end

  context 'from the profile page' do
    let(:user) { users.usager }
    let(:weak_password) { '000000000000' }
    let(:strong_password) { 'a new, long, and complicated password!' }

    before { login_as user, scope: :user }

    scenario 'a signed-in user changes their password' do
      visit profil_path
      click_on 'Modifier mon mot de passe'

      fill_in 'Mot de passe actuel', with: users.default_password
      fill_in 'user_password', with: weak_password
      fill_in 'user_password_confirmation', with: weak_password
      expect(page).to have_text('Mot de passe très vulnérable')
      expect(page).to have_button('Changer le mot de passe', disabled: true)

      fill_in 'user_password', with: strong_password
      fill_in 'user_password_confirmation', with: strong_password
      expect(page).to have_text('Mot de passe suffisamment fort et sécurisé')

      perform_enqueued_jobs { click_on 'Changer le mot de passe' }
      expect(page).to have_current_path(profil_path)
      expect(page).to have_content('Votre mot de passe a bien été modifié')

      # La session courante doit survivre au changement : sans bypass_sign_in,
      # Devise deconnecte l'utilisateur au prochain chargement de page.
      visit dossiers_path
      expect(page).to have_current_path(dossiers_path)
    end

    # Devise refuse tout le parcours « mot de passe oublié » a un utilisateur
    # connecté, lien reçu par mail compris. Ce scénario va donc jusqu'au bout
    # pour garantir qu'aucune étape ne rebondit vers l'accueil.
    scenario 'a user who does not know their current password resets it' do
      visit edit_profil_password_path

      click_on 'Réinitialiser mon mot de passe'
      expect(page).to have_current_path(new_user_password_path)

      fill_in 'Adresse électronique', with: user.email
      perform_enqueued_jobs { click_on 'Demander un nouveau mot de passe' }
      expect(page).to have_text 'nous vous avons envoyé un email'

      click_reset_password_link_for user.email
      expect(page).to have_content 'Changement de mot de passe'

      fill_in 'user_password', with: strong_password
      fill_in 'user_password_confirmation', with: strong_password
      click_on 'Changer le mot de passe'

      expect(page).to have_content('Votre mot de passe a bien été modifié.')
      expect(user.reload.valid_password?(strong_password)).to be true
    end

    scenario 'a wrong current password is rejected' do
      visit edit_profil_password_path

      fill_in 'Mot de passe actuel', with: 'ce n’est pas le bon mot de passe'
      fill_in 'user_password', with: strong_password
      fill_in 'user_password_confirmation', with: strong_password
      click_on 'Changer le mot de passe'

      expect(page).to have_text('est incorrect')
      expect(user.reload.valid_password?(strong_password)).to be false
    end
  end

  scenario 'the password reset token has expired' do
    visit edit_user_password_path(reset_password_token: 'invalid-password-token')
    expect(page).to have_content 'Changement de mot de passe'

    fill_in 'user_password', with: SECURE_PASSWORD
    fill_in 'user_password_confirmation', with: SECURE_PASSWORD
    click_on 'Changer le mot de passe'
    expect(page).to have_content('Votre lien de nouveau mot de passe a expiré')
  end
end
