# frozen_string_literal: true

describe 'Managing my active sessions', js: true do
  let(:password) { users.default_password }
  let(:user) { create(:user, password:) }

  let(:android) do
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36'
  end

  scenario 'I see the browser I am signed in with, and close another one' do
    other_device = user.open_user_session!(android)

    visit new_user_session_path
    sign_in_with(user.email, password)

    visit profil_path

    expect(page).to have_text('Mes sessions actives')
    expect(page).to have_text('Chrome sur Android')
    expect(page).to have_text('Session actuelle')

    accept_confirm { find("[aria-label^='Déconnecter l’appareil Chrome sur Android']").click }

    expect(page).to have_text('L’appareil a été déconnecté.')
    expect(other_device.reload).to be_unusable
    expect(page).not_to have_text('Chrome sur Android')
  end

  scenario 'I close every other device and stay signed in' do
    other_device = user.open_user_session!(android)

    visit new_user_session_path
    sign_in_with(user.email, password)

    visit profil_path
    accept_confirm { click_on 'Déconnecter les autres appareils' }

    expect(page).to have_text('Vos autres appareils ont été déconnectés.')
    expect(page).not_to have_text('Chrome sur Android')
    expect(other_device.reload).to be_unusable

    visit dossiers_path

    expect(page).to have_current_path(dossiers_path)
  end
end
