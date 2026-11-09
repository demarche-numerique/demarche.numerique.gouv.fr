# frozen_string_literal: true

describe 'signing in with a password from an administrateur device', :allow_forgery_protection, type: :request do
  let(:user) { users.usager }

  before { cookies[ProConnectSessionConcern::ADMINISTRATEUR_DEVICE_COOKIE_NAME] = '1' }

  it 'shows the password form again after a wrong password' do
    get new_user_session_path(with_particulier: true)
    form = Capybara.string(response.body).find('form#new_user')
    hidden_fields = form.all('input[type=hidden]').to_h { [it[:name], it[:value]] }

    post form[:action], params: hidden_fields.merge('user[email]' => user.email, 'user[password]' => 'wrong password')

    page = Capybara.string(response.body)
    expect(page).to have_text('mot de passe incorrect')
    expect(page).to have_field('user[password]')
  end
end
