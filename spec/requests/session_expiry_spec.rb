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

    it 'is still signed in three months in: the year is housekeeping, not a policy' do
      travel(3.months) do
        get profil_path

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
