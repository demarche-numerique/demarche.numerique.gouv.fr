# frozen_string_literal: true

describe 'the locale stored on the account', type: :request do
  let(:user) { users.usager }

  before { login_as(user, scope: :user) }

  it 'stores the locale the user browses in when the account has none' do
    get '/contact', headers: { 'Accept-Language' => 'en-US,en' }

    expect(user.reload.locale).to eq('en')
  end

  it 'keeps the locale already stored on the account' do
    user.update!(locale: 'fr')
    get '/contact', headers: { 'Accept-Language' => 'en-US,en' }

    expect(user.reload.locale).to eq('fr')
  end
end
