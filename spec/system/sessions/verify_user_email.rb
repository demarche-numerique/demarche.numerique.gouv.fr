# frozen_string_literal: true

describe 'Not verified users are warned and able to act on:', js: true do
  let(:user) { create(:user, email_verified_at: nil) }
  before { login_as user, scope: :user }

  scenario 'user has not his verified email' do
    visit root_path
    expect(page).to have_content("Votre adresse électronique n’est pas vérifiée")

    perform_enqueued_jobs do
      click_on 'Renvoyer l’email de vérification'
    end

    click_verification_link_for(user.email)

    expect(page).not_to have_content("Votre adresse électronique n’est pas vérifiée")
    user.reload
    expect(user.email_verified_at).to be_present
  end
end
