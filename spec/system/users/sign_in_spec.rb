# frozen_string_literal: true

describe 'Sign in', js: true do
  let(:user) { create(:user) }

  before { allow(FranceConnectService).to receive(:enabled?).and_return(true) }

  scenario 'when a user is logged in english' do
    visit root_path

    within(".fr-header__tools") do
      find('.fr-translate__btn').click
    end
    within("#translate") do
      click_on("EN - English")
    end
    expect(page).to have_content("Sign in")
    within(".fr-header__tools") do
      click_on("Sign in")
    end
    expect(page).to have_content("Sign in with FranceConnect")
    fill_in(:user_email, with: user.email)
    fill_in(:user_password, with: 'wrong password')
    click_on("Sign in")
    expect(page).to have_content("Invalid Email or password.")
  end
end
