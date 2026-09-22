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

    # The deadline is the age of the session, not its idleness: the request on
    # day six above does not push it back. A Devise timeout would keep this
    # account signed in forever.
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

    it 'stays signed in as long as it keeps coming back' do
      travel(10.days) { get profil_path }
      travel(20.days) { get profil_path }

      travel(30.days) do
        get profil_path

        expect(response).to have_http_status(:ok)
      end
    end

    it 'is signed out two weeks after its last visit' do
      travel(15.days) do
        get profil_path

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq(I18n.t('devise.failure.inactivity'))
      end
    end

    # The hooks rescue everything into Sentry, so a raise here would be invisible
    # but for the noise: `warden.session` raises once the scope is logged out.
    it 'signs out without raising behind the rescue' do
      expect(Sentry).not_to receive(:capture_exception)

      travel(15.days) { get profil_path }
    end

    # The row is the durable trace. Left to `before_logout` it would read
    # `sign_out`, and the session list would say the user left on purpose.
    it 'records why, and not as a sign out' do
      travel(15.days) { get profil_path }

      expect(user.user_sessions.sole.revoked_reason).to eq('inactivity')
    end

    # The policy is frozen with the session, like `expires_at` on the row:
    # gaining a role mid-session must not drop the bound the session opened
    # under -- which is what recomputing it from today's roles did.
    it 'keeps its window after being invited as an expert' do
      user.create_expert!

      travel(15.days) do
        get profil_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it 'is not bounded by an absolute deadline the way an agent is' do
      expect(user.session_max_lifetime).to eq(User::USAGER_SESSION_MAX_LIFETIME)
      expect(user.session_inactivity_window).to eq(User::USAGER_SESSION_INACTIVITY_WINDOW)
    end
  end

  # Rows written before roles had deadlines carry none, and the `usable` scope
  # treats a nil deadline as forever.
  # The inactivity check is gated; the stamp that feeds it is not. Were it gated
  # too, closing the flag would freeze `last_seen_on` and opening it again would
  # sign every active user out at once.
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

  context 'a session registered before deadlines existed' do
    let(:user) { create(:user, password:) }

    before do
      Flipper.enable_actor(:session_registry, user)
      post_session(user)
      user.user_sessions.sole.update_column(:expires_at, nil)
    end

    it 'is given one, counted from when it opened' do
      row = user.user_sessions.sole

      travel(1.day) { get profil_path }

      expect(row.reload.expires_at)
        .to be_within(1.minute).of(row.created_at + User::USAGER_SESSION_MAX_LIFETIME)
    end

    it 'signs out an agent whose deadline had already passed' do
      create(:administrateur, user:)
      user.user_sessions.sole.update_column(:expires_at, nil)

      travel(8.days) do
        get profil_path

        expect(response).to redirect_to(new_user_session_path)
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

    # Promoted through a record loaded from a query, as every real promotion
    # path does: User eager loads its roles, so the association answers `nil`
    # from cache inside the `after_create` unless the record is reloaded.
    it 'has its deadline shortened to the new role, not extended' do
      row = user.user_sessions.sole
      expect(row.expires_at).to be_within(1.minute).of(row.created_at + User::USAGER_SESSION_MAX_LIFETIME)

      User.find(user.id).create_expert!

      expect(row.reload.expires_at)
        .to be_within(1.minute).of(row.created_at + TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD)
    end
  end

  context 'an agent' do
    let(:user) { create(:administrateur).user }

    it 'has no sliding window: its absolute deadline is the whole policy' do
      expect(user.session_inactivity_window).to be_nil
    end
  end
end
