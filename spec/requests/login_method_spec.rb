# frozen_string_literal: true

describe 'how a session was opened', type: :request do
  let(:user) { users.usager }

  it 'records a sign in through the form as a password one' do
    post_user_session(user)

    expect(UserSession.where(sessionable: user).sole.login_method).to eq('password')
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
end
