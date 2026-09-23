# frozen_string_literal: true

describe 'the session failure app', type: :request do
  let(:password) { users.default_password }
  let(:usager) { create(:user, password:) }

  before { Flipper.enable_actor(:session_registry, usager) }

  def sign_in_usager
    post user_session_path, params: { user: { email: usager.email, password: } }
  end

  context 'when the session has been revoked' do
    before do
      sign_in_usager
      usager.revoke_sessions!(reason: :logout_all)
    end

    it 'redirects an ordinary request, and says why' do
      get profil_path

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(I18n.t('devise.failure.logout_all'))
    end

    it 'answers a bare 401 to a turbo stream request' do
      get profil_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to be_empty
    end

    # The client must not invent the path: each Warden scope has its own sign in
    # page, and /users/sign_in is not /super_admins/sign_in.
    it 'tells the browser where to go, in a header' do
      get profil_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response.headers['X-Sign-In-Path']).to end_with(new_user_session_path)
    end

    it 'still explains itself after the turbo path, and does not repeat itself' do
      get profil_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(flash[:alert]).to eq(I18n.t('devise.failure.logout_all'))

      # A wrong password must not be answered with "you signed out everywhere".
      post user_session_path, params: { user: { email: usager.email, password: 'nope' } }
      expect(flash[:alert]).not_to eq(I18n.t('devise.failure.logout_all'))
    end

    it 'answers a bare 401 inside a turbo frame' do
      get profil_path, headers: { 'Turbo-Frame' => 'whatever' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'reads the reason once, so the next failure does not inherit it' do
      get profil_path
      get profil_path

      expect(flash[:alert]).to eq(I18n.t('devise.failure.unauthenticated'))
    end
  end

  # The failure app sees every authentication failure, ordinary ones included.
  it 'leaves a wrong password on the sign in form, without a 401' do
    post user_session_path, params: { user: { email: usager.email, password: 'not-the-password' } }

    # 422 is what Devise answers a Turbo form submission it re-renders. What
    # matters is that the form comes back with its error, and not a bare 401.
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('user[password]')
  end
end
