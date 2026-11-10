# frozen_string_literal: true

describe 'how a session was opened', type: :request do
  let(:user) { users.usager }

  it 'records a sign in through the form as a password one' do
    post_user_session(user)

    expect(UserSession.where(sessionable: user).sole.login_method).to eq('password')
  end

  describe 'reading it back' do
    def logged_in_with
      get dossiers_path

      {
        france_connect: controller.logged_in_with_france_connect?,
        pro_connect: controller.logged_in_with_pro_connect?,
      }
    end

    it 'reads it off the row of the session' do
      login_as(user, scope: :user, event: :set_user, login_method: :france_connect)

      expect(logged_in_with).to eq(france_connect: true, pro_connect: false)
    end

    # Sessions opened before their row recorded how
    context 'when the row does not say' do
      before { login_as(user, scope: :user, event: :set_user) }

      it 'reads the ProConnect cookie' do
        jar = ActionDispatch::TestRequest.create.cookie_jar
        jar.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = { user_id: user.id }.to_json
        cookies[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = jar[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME]

        expect(logged_in_with).to eq(france_connect: false, pro_connect: true)
      end

      it 'reads the FranceConnect column of the account' do
        user.update!(loged_in_with_france_connect: 'particulier')

        expect(logged_in_with).to eq(france_connect: true, pro_connect: false)
      end

      it 'knows nothing otherwise' do
        expect(logged_in_with).to eq(france_connect: false, pro_connect: false)
      end
    end
  end
end
