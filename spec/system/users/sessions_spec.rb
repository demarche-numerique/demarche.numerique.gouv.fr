# frozen_string_literal: true

describe 'Managing my active sessions', js: true do
  let(:password) { users.default_password }
  let(:user) { create(:user, password:) }
  let(:firefox) { 'Mozilla/5.0 (X11; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0' }

  before { Flipper.enable_actor(:session_registry, user) }

  scenario 'I see the browser I am signed in with, and close another one' do
    other_device = user.open_user_session!(firefox)

    visit new_user_session_path
    sign_in_with(user.email, password)

    visit profil_path

    expect(page).to have_text('Mes sessions actives')
    # Two rows: the browser running this test, and the one seeded above.
    expect(page).to have_text('Firefox sur Linux')
    expect(page).to have_text('Session actuelle')

    accept_confirm { click_on "Déconnecter l’appareil Firefox sur Linux" }

    expect(page).to have_text('L’appareil a été déconnecté.')
    expect(other_device.reload).to be_unusable
    expect(page).not_to have_text('Firefox sur Linux')
  end

  # Closing everything closes this browser too. Sparing it would leave it signed
  # in while the account-wide trusted device bump treats it as untrusted, so it
  # would be signed in and stuck on the next sensitive page.
  scenario 'I close every device, this one included' do
    user.open_user_session!(firefox)

    visit new_user_session_path
    sign_in_with(user.email, password)

    visit profil_path
    accept_confirm { click_on 'Déconnecter tous les appareils' }

    expect(page).to have_text('Tous vos appareils ont été déconnectés.')

    visit dossiers_path

    expect(page).to have_current_path(new_user_session_path)
  end
end
