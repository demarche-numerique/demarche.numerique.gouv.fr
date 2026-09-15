# frozen_string_literal: true

describe 'the remember me window', type: :request do
  let(:password) { users.default_password }
  let(:usager) { create(:user, password:) }
  let(:agent) { create(:instructeur).user }

  # Never `sign_in`: it skips the Warden strategies, and the remember cookie is
  # precisely what they produce.
  def post_session(user, remember_me:)
    post user_session_path,
      params: { user: { email: user.email, password: user.password, remember_me: remember_me ? '1' : '0' } }
  end

  def close_the_browser = cookies.delete('_DS_session')

  describe 'who gets a remember cookie' do
    it 'is issued to an usager who asked for it' do
      post_session(usager, remember_me: true)

      expect(cookies['remember_user_token']).to be_present
    end

    it 'is not issued to an usager who did not ask' do
      post_session(usager, remember_me: false)

      expect(cookies['remember_user_token']).to be_blank
    end

    it 'is never issued to an agent, even when asked for' do
      agent.update!(password:)

      post_session(agent, remember_me: true)

      expect(cookies['remember_user_token']).to be_blank
    end
  end

  describe 'the window' do
    before do
      post_session(usager, remember_me: true)
      close_the_browser
    end

    it 'slides on every use, so coming back every ten days never signs anyone out' do
      travel(10.days) do
        get profil_path
        expect(response).to have_http_status(:ok)
      end

      # Twenty days after the sign in, so past `remember_for`, but only ten days
      # since the cookie was last used. Without `extend_remember_period` this
      # second request would land on the sign in page.
      travel(20.days) do
        close_the_browser
        get profil_path

        expect(response).to have_http_status(:ok)
      end
    end

    it 'closes after two weeks without a visit' do
      travel(15.days) do
        get profil_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
