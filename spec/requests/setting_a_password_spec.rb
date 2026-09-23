# frozen_string_literal: true

# Setting a password revokes every session of the account -- the one the visitor
# is sitting on included, and the trust their browser had earned. The two paths
# that set a password outside Devise's own controller have to hand both back.
describe 'setting a password outside the reset form', type: :request do
  let(:password) { users.default_password }
  let(:new_password) { '{An0ther-$3cure-p4ssWord}' }
  let(:user) { users.usager }

  before do
    Flipper.enable_actor(:session_registry, user)
    post_user_session(user)

    set_the_password
  end

  shared_examples 'a password set on a live session' do
    it 'leaves the visitor signed in' do
      get profil_path

      expect(response).to have_http_status(:ok)
    end

    it 'opens exactly one session, in place of the revoked one' do
      expect(user.user_sessions.usable.count).to eq(1)
    end
  end

  # Devise's `sign_in` does nothing when the visitor already is that user, so
  # without `force` the cookie keeps naming the row the password change killed.
  describe 'activating an account while already signed in on it' do
    def set_the_password
      patch users_activate_path, params: {
        user: {
          reset_password_token: user.send_reset_password_instructions,
          password: new_password,
        },
      }
    end

    it_behaves_like 'a password set on a live session'
  end

  # Devise's own account page re-establishes the session with `bypass_sign_in`,
  # which fires no Warden event, so nothing would open the replacement the
  # revocation just made necessary.
  describe 'changing the password from the account page' do
    def set_the_password
      put user_registration_path, params: {
        user: { current_password: password, password: new_password, password_confirmation: new_password },
      }
    end

    it_behaves_like 'a password set on a live session'
  end
end
