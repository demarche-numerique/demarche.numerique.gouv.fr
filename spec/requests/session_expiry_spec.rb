# frozen_string_literal: true

describe 'session deadlines', type: :request do
  let(:password) { users.default_password }

  def post_session(user)
    post user_session_path, params: { user: { email: user.email, password: } }
  end

  context 'an administrateur' do
    let(:user) { create(:administrateur).user }

    before do
      user.update!(password:)
      Flipper.enable_actor(:session_registry, user)
      post_session(user)
    end

    it 'is still signed in six days in' do
      travel(6.days) do
        get profil_path

        expect(response).to have_http_status(:ok)
      end
    end

    # The age of the session, not its idleness: the request on day six does
    # not push it back.
    it 'is signed out a week in, even though it stayed active' do
      travel(6.days) { get profil_path }

      travel(8.days) do
        get profil_path

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq(I18n.t('devise.failure.expired'))
      end
    end
  end

  context 'an usager' do
    let(:user) { create(:user, password:) }

    before do
      Flipper.enable_actor(:session_registry, user)
      post_session(user)
    end

    it 'is not bounded by an absolute deadline the way an agent is' do
      expect(user.session_max_lifetime).to eq(User::USAGER_SESSION_MAX_LIFETIME)
    end
  end

  # The check is gated; the stamp that feeds it is not. Gating both would
  # freeze `last_seen_on` and sign everyone out when the flag reopened.
  context 'the registry flag closed, then opened again' do
    let(:user) { create(:user, password:) }

    before do
      Flipper.enable_actor(:session_registry, user)
      post_session(user)
    end

    it 'does not sign out someone who kept coming back meanwhile' do
      Flipper.disable_actor(:session_registry, user)

      travel(10.days) { get profil_path }
      travel(20.days) { get profil_path }

      Flipper.enable_actor(:session_registry, user)

      travel(25.days) do
        get profil_path

        expect(response).to have_http_status(:ok)
      end
    end
  end

  # The deadline is frozen, but a role granted mid-session must not leave the
  # session living under the year an usager gets.

  context 'an usager promoted while signed in' do
    let(:user) { create(:user, password:) }

    before do
      Flipper.enable_actor(:session_registry, user)
      post_session(user)
    end

    # Through a record loaded from a query, as every real promotion path does:
    # User eager loads its roles, so the association answers nil from cache.
    it 'has its deadline shortened to the new role, not extended' do
      row = user.user_sessions.sole
      expect(row.expires_at).to be_within(1.minute).of(row.created_at + User::USAGER_SESSION_MAX_LIFETIME)

      User.find(user.id).create_expert!

      expect(row.reload.expires_at)
        .to be_within(1.minute).of(row.created_at + TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD)
    end
  end

  # The same for everyone. It only shows for roles whose absolute deadline is
  # longer -- an administrateur is out after a week whatever they do.
end
