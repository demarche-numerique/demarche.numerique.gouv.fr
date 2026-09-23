# frozen_string_literal: true

# "Se souvenir de moi" is an expiry on the session cookie, not a second cookie
# that signs you back in. The row it names is still checked on every request.
describe 'staying signed in', type: :request do
  let(:password) { users.default_password }

  def post_session(user, remember_me:)
    post user_session_path,
      params: { user: { email: user.email, password:, remember_me: remember_me ? '1' : '0' } }
  end

  def session_cookie
    Array(response.headers['Set-Cookie'])
      .flat_map { |header| header.split("\n") }
      .find { |line| line.start_with?('_DS_session=') }
  end

  def session_cookie_expiry
    matched = session_cookie&.match(/expires=([^;]+)/i)

    Time.zone.parse(matched[1]) if matched
  end

  context 'an usager who ticked the box' do
    let(:usager) { create(:user, password:) }

    it 'gets a cookie that outlives the browser' do
      post_session(usager, remember_me: true)

      expect(session_cookie_expiry)
        .to be_within(1.day).of(SessionRegistrableConcern::SESSION_COOKIE_LIFETIME.from_now)
    end

    # Rails rewrites the cookie on every response; a rewrite with no expiry
    # would quietly turn it back into a session cookie.
    it 'keeps the expiry on the requests that follow' do
      post_session(usager, remember_me: true)

      get profil_path

      expect(session_cookie_expiry).to be_present
    end
  end

  # Rack recomputes the expiry on every response, so the window slides without
  # a line of our own -- as long as the option is set again each time.
  context 'the window' do
    let(:usager) { create(:user, password:) }

    it 'slides with use' do
      post_session(usager, remember_me: true)
      first = session_cookie_expiry

      travel(3.days) do
        get profil_path

        expect(session_cookie_expiry).to be > first
      end
    end
  end

  context 'an usager who did not tick it' do
    let(:usager) { create(:user, password:) }

    it 'gets a session cookie, which dies with the browser' do
      post_session(usager, remember_me: false)

      expect(session_cookie).to be_present
      expect(session_cookie_expiry).to be_nil
    end
  end

  # The checkbox lives on the sign in form. Every other way of opening a session
  # -- FranceConnect, an invitation, an activation link -- says nothing about it,
  # and must not be read as saying no.
  context 'a programmatic sign in, after the box was ticked' do
    it 'leaves the choice alone' do
      post_session(usager, remember_me: true)

      patch users_activate_path, params: {
        user: {
          reset_password_token: usager.send_reset_password_instructions,
          password: '{An0ther-$3cure-p4ssWord}',
        },
      }

      get profil_path

      expect(session_cookie_expiry).to be_present
    end
  end

  # One duration for everyone. What differs per role is the row, and the row
  # is what actually cuts.
  context 'an agent' do
    let(:agent) { create(:instructeur).user }

    before { agent.update!(password:) }

    it 'gets the same cookie as anyone else' do
      post_session(agent, remember_me: true)

      expect(session_cookie_expiry)
        .to be_within(1.day).of(SessionRegistrableConcern::SESSION_COOKIE_LIFETIME.from_now)
    end
  end
end
