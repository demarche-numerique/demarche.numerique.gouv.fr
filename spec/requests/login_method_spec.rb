# frozen_string_literal: true

describe 'how a session was opened', type: :request do
  let(:user) { users.usager }

  it 'records a sign in through the form as a password one' do
    post_user_session(user)

    expect(UserSession.where(sessionable: user).sole.login_method).to eq('password')
  end

  it 'refuses a sign in by application code that does not say how' do
    login_as(user, scope: :user, event: :set_user)

    expect { get dossiers_path }.to raise_error(KeyError, /login_method/)
  end

  describe 'reading it back' do
    # Read while the request runs: `Current` is reset once it is over.
    def login_method_read
      read = nil
      during_request = -> (*) { read = Current.user_session&.login_method }

      ActiveSupport::Notifications.subscribed(during_request, 'process_action.action_controller') { get dossiers_path }

      read
    end

    it 'reads it off the row of the session' do
      login_as(user, scope: :user, event: :set_user, login_method: :france_connect)

      expect(login_method_read).to eq('france_connect')
    end

    it "reads the usager's row when a super admin is signed in too" do
      login_as(user, scope: :user, event: :set_user, login_method: :pro_connect)
      login_as(create(:super_admin), scope: :super_admin, event: :set_user, login_method: :password)

      expect(login_method_read).to eq('pro_connect')
    end
  end

  describe 'a session opened before the method was recorded' do
    before { login_as(user, scope: :user, event: :set_user, login_method: nil) }

    def set_encrypted_cookie(name, value)
      jar = ActionDispatch::TestRequest.create.cookie_jar
      jar.encrypted[name] = value
      cookies[name] = jar[name]
    end

    def login_method_after_a_request
      get dossiers_path

      UserSession.where(sessionable: user).sole.login_method
    end

    it 'takes ProConnect from its cookie' do
      set_encrypted_cookie(ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME, { user_id: user.id }.to_json)

      expect(login_method_after_a_request).to eq('pro_connect')
    end

    it "takes FranceConnect from the id token of the account's identity" do
      create(:france_connect_information, user:, france_connect_particulier_id: 'sub-of-the-usager')
      set_encrypted_cookie(FranceConnectController::ID_TOKEN_COOKIE_NAME, JSON::JWT.new(sub: 'sub-of-the-usager').to_s)

      expect(login_method_after_a_request).to eq('france_connect')
    end

    it 'takes a password when no provider left a cookie' do
      expect(login_method_after_a_request).to eq('password')
    end

    it 'ignores the id token of another identity' do
      set_encrypted_cookie(FranceConnectController::ID_TOKEN_COOKIE_NAME, JSON::JWT.new(sub: 'sub-of-someone-else').to_s)

      expect(login_method_after_a_request).to eq('password')
    end

    it 'ignores an id token it cannot read' do
      set_encrypted_cookie(FranceConnectController::ID_TOKEN_COOKIE_NAME, 'not-a-jwt')

      expect(login_method_after_a_request).to eq('password')
    end
  end
end
