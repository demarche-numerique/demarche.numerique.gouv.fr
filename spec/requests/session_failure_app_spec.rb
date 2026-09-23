# frozen_string_literal: true

describe 'the session failure app', type: :request do
  # No seeded super admin: the OTP secret is the point of this one.
  let_it_be(:super_admin) { create(:super_admin, :with_otp) }

  let(:password) { users.default_password }
  let(:usager) { users.usager }

  before { Flipper.enable_actor(:session_registry, usager) }

  context 'when the session has been revoked' do
    before do
      post_user_session(usager)
      usager.revoke_sessions!(reason: :logout_all)
    end

    it 'redirects an ordinary request, and says why' do
      get profil_path

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(I18n.t('devise.failure.logout_all'))
    end

    # A stream or a form submission follows a redirect perfectly well; only a
    # frame cannot, so only a frame is answered with a 401.
    it 'redirects a turbo stream request, like any other' do
      get profil_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'answers a bare 401 inside a turbo frame, and nothing else' do
      get profil_path, headers: { 'Turbo-Frame' => 'a-modal' }

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to be_empty
    end

    # The client must not invent the path: each Warden scope has its own sign in
    # page, and /users/sign_in is not /super_admins/sign_in.
    it 'tells the browser where to go, in a header' do
      get profil_path, headers: { 'Turbo-Frame' => 'a-modal' }

      expect(response.headers['X-Sign-In-Path']).to end_with(new_user_session_path)
    end

    it 'still explains itself after the turbo path, and does not repeat itself' do
      get profil_path, headers: { 'Turbo-Frame' => 'a-modal' }
      expect(flash[:alert]).to eq(I18n.t('devise.failure.logout_all'))

      # A wrong password must not be answered with "you signed out everywhere".
      post user_session_path, params: { user: { email: usager.email, password: 'nope' } }
      expect(flash[:alert]).not_to eq(I18n.t('devise.failure.logout_all'))
    end

    # Devise answers an XHR client a 401 carrying the message. Turbo does not
    # set X-Requested-With, so the two never overlap -- but an XHR that also
    # advertises turbo-stream must keep the body it had.
    it 'leaves an XHR client the 401 body Devise gives it' do
      get profil_path, xhr: true, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to eq(I18n.t('devise.failure.logout_all'))
    end

    # The frame URL is a fragment; where they were is the page around it.
    it 'sends them back to the page around the frame after signing in' do
      get profil_path,
        headers: { 'Turbo-Frame' => 'a-modal', 'Referer' => "http://www.example.com#{dossiers_path}?page=2" }

      expect(session['user_return_to']).to eq("#{dossiers_path}?page=2")
    end

    it 'refuses a referer pointing somewhere else entirely' do
      get profil_path,
        headers: { 'Turbo-Frame' => 'a-modal', 'Referer' => 'https://evil.example.org/phishing' }

      expect(session['user_return_to']).to eq(profil_path)
    end

    # Storing nothing would send them to the root after signing in; Devise's own
    # rule -- the path they attempted -- is a better answer than none.
    it 'falls back to the attempted path when the referer is unusable' do
      get profil_path, headers: { 'Turbo-Frame' => 'a-modal' }

      expect(session['user_return_to']).to eq(profil_path)
    end

    # The reason exists only on the first rejected request: the scope is logged
    # out by then, so nothing recomputes it. The app's fetch helper reloads and
    # throws the 401 body away, so the flash has to carry it.
    it 'still explains itself when the 401 body is thrown away' do
      get profil_path, xhr: true
      expect(response).to have_http_status(:unauthorized)

      # What the fetch helper does with that 401: reload, and land on the sign
      # in page through one more failure that has no reason left to compute.
      get profil_path
      follow_redirect!

      expect(response.body).to include(I18n.t('devise.failure.logout_all'))
    end

    it 'reads the reason once, so the next failure does not inherit it' do
      get profil_path
      get profil_path

      expect(flash[:alert]).to eq(I18n.t('devise.failure.unauthenticated'))
    end
  end

  # Two scopes share one request. The usager's session is fetched by
  # `set_sentry_user` on every page, the manager's by its own filter.
  it 'does not show one scope reason on another scope sign in page' do
    Flipper.enable_actor(:session_registry, super_admin)

    post_user_session(usager)
    usager.revoke_sessions!(reason: :logout_all)

    get manager_root_path

    expect(response).to redirect_to(new_super_admin_session_path)
    expect(flash[:alert]).to eq(I18n.t('devise.failure.unauthenticated'))
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
