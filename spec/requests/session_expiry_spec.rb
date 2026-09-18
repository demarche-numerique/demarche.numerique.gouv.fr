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

  context 'an agent' do
    let(:user) { create(:administrateur).user }

    it 'has no sliding window: its absolute deadline is the whole policy' do
      expect(user.session_inactivity_window).to be_nil
    end
  end
end
