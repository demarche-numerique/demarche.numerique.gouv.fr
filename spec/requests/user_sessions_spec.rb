# frozen_string_literal: true

describe 'the session registry', type: :request do
  let(:super_admin) { create(:super_admin, :with_otp) }
  let(:chrome_on_mac) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36" }

  def sign_in_super_admin = post_super_admin_session(super_admin, user_agent: chrome_on_mac)

  def super_admin_sessions = UserSession.where(sessionable: super_admin)

  context 'when the feature is open for the account' do
    before { Flipper.enable_actor(:session_registry, super_admin) }

    it 'registers a row when a super admin signs in' do
      expect { sign_in_super_admin }.to change { super_admin_sessions.count }.by(1)
    end

    it 'keeps the user agent, so the label can be derived at display time' do
      sign_in_super_admin

      expect(super_admin_sessions.sole.user_agent).to eq(chrome_on_mac)
    end

    # Recorded once, when the session opens. It is what makes a session opened
    # from somewhere unexpected recognisable.
    it 'records the address the session was opened from' do
      sign_in_super_admin

      expect(super_admin_sessions.sole.ip_address).to eq(IPAddr.new('127.0.0.1'))
    end

    # The row is read on every request; rewriting it on a changed address would
    # turn that read into a write, on every request of every signed in account.
    it 'leaves that address alone once the session is open' do
      sign_in_super_admin

      get manager_root_path, headers: { 'REMOTE_ADDR' => '10.11.12.13' }

      expect(super_admin_sessions.sole.ip_address).to eq(IPAddr.new('127.0.0.1'))
    end

    # The user agent is a header, so a client can send bytes that are not valid
    # UTF-8. Postgres refuses such an INSERT, the hook rescues it, and the session
    # would open with no row: no deadline, and out of reach of revocation. One
    # header would have exempted a session from the whole mechanism.
    it 'still registers a row when the user agent is not valid UTF-8' do
      broken = "Mozilla/5.0 \xC3\x28".dup.force_encoding(Encoding::BINARY)

      expect { post_super_admin_session(super_admin, user_agent: broken) }
        .to change { super_admin_sessions.count }.by(1)

      expect(super_admin_sessions.sole.user_agent).to eq('Mozilla/5.0 (')
    end

    it 'lets a live session through' do
      sign_in_super_admin

      get manager_root_path

      expect(response).to have_http_status(:ok)
    end

    it 'rejects the next request once the row is revoked' do
      sign_in_super_admin
      super_admin.revoke_sessions!(reason: :logout_all)

      get manager_root_path

      expect(response).to redirect_to(new_super_admin_session_path)
    end

    it 'adopts a session opened before the registry rather than reject it' do
      Flipper.disable_actor(:session_registry, super_admin)
      sign_in_super_admin
      expect(super_admin_sessions).to be_empty
      Flipper.enable_actor(:session_registry, super_admin)

      get manager_root_path

      expect(response).to have_http_status(:ok)
      expect(super_admin_sessions.count).to eq(1)
    end

    it 'signs nobody out when the hook raises' do
      sign_in_super_admin
      allow(UserSession).to receive(:find_by).and_raise('boom')
      expect(Sentry).to receive(:capture_exception)

      get manager_root_path

      expect(response).to have_http_status(:ok)
    end

    it 'rejects a session whose row no longer exists' do
      sign_in_super_admin
      super_admin.user_sessions.destroy_all

      get manager_root_path

      expect(response).to redirect_to(new_super_admin_session_path)
    end

    # The scope is emptied, not the request aborted: a page that merely probes
    # for a super admin keeps working for whoever is actually browsing it.
    it 'leaves a request that only probes for a super admin alone' do
      sign_in_super_admin
      super_admin.revoke_sessions!(reason: :logout_all)

      get contact_path

      expect(response).to have_http_status(:ok)
    end

    it 'lets the request through when the feature check itself raises' do
      sign_in_super_admin
      allow(Flipper).to receive(:enabled?).and_call_original
      allow(Flipper).to receive(:enabled?).with(:session_registry, anything).and_raise('flipper is down')
      expect(Sentry).to receive(:capture_exception)

      get manager_root_path

      expect(response).to have_http_status(:ok)
    end

    it 'revokes the row on sign out, with reason sign_out' do
      sign_in_super_admin

      delete destroy_super_admin_session_path

      expect(super_admin_sessions.sole.unusable_reason).to eq(:sign_out)
    end
  end

  context 'when the feature is closed for the account' do
    it 'lets a revoked session through: the hook is a no-op' do
      Flipper.enable_actor(:session_registry, super_admin)
      sign_in_super_admin
      super_admin.revoke_sessions!(reason: :logout_all)
      Flipper.disable_actor(:session_registry, super_admin)

      get manager_root_path

      expect(response).to have_http_status(:ok)
    end
  end

  context 'when a usager signs in' do
    let(:user) { users.usager }

    before { Flipper.enable_actor(:session_registry, user) }

    def sign_in_user
      post user_session_path,
        params: { user: { email: user.email, password: users.default_password } },
        headers: { 'HTTP_USER_AGENT' => chrome_on_mac }
    end

    def user_sessions = UserSession.where(sessionable: user)

    it 'registers a row' do
      expect { sign_in_user }.to change { user_sessions.count }.by(1)
    end

    # Devise's `sign_in` raises the :set_user event, not :authentication. Every
    # federated and link-based path signs people in that way -- FranceConnect,
    # ProConnect, invitations, email confirmation, password reset, expert links
    # -- so keying the row on :authentication alone left all of them without
    # one. Adoption used to paper over it; without adoption they loop back to
    # the sign in page forever.
    #
    # This is the first step where the hook can be exercised on that half: a
    # super admin never reaches a `sign_in` in test, OTP being forced on there.
    context 'through a path that calls Devise sign_in, as the activation link does' do
      let(:user) { create(:user) }
      let(:token) { user.send(:set_reset_password_token) }
      let(:new_password) { "#{users.default_password} (neuf)" }

      before { Flipper.enable_actor(:session_registry, user) }

      def activate
        patch users_activate_path,
          params: { user: { reset_password_token: token, password: new_password } }
      end

      it 'registers a row and lets the next request through' do
        expect { activate }.to change { UserSession.where(sessionable: user).count }.by(1)

        get profil_path

        expect(response).to have_http_status(:ok)
      end
    end

    # Usagers have no deadline until step 8. Opening the registry to everyone
    # must not expire anyone.
    it 'gives that row no deadline' do
      sign_in_user

      expect(user_sessions.sole.expires_at).to be_nil
    end

    it 'adopts a session opened before the registry rather than reject it' do
      Flipper.disable_actor(:session_registry, user)
      sign_in_user
      expect(user_sessions).to be_empty
      Flipper.enable_actor(:session_registry, user)

      get dossiers_path

      expect(response).to have_http_status(:ok)
      expect(user_sessions.count).to eq(1)
    end
  end
end
