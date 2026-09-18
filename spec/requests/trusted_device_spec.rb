# frozen_string_literal: true

describe 'Trusted device (second factor by email link)', type: :request do
  let(:password) { SECURE_PASSWORD }
  let(:instructeur) { create(:instructeur, bypass_email_login_token: false, password:) }
  let(:other_instructeur) { create(:instructeur, bypass_email_login_token: false, password:) }
  let(:token) { instructeur.create_trusted_device_token }

  def sign_in_with(user)
    post user_session_path, params: { user: { email: user.email, password: } }
  end

  def sign_out!
    delete destroy_user_session_path
  end

  def trusted_device_cookie
    cookies[TrustedDeviceConcern::TRUSTED_DEVICE_COOKIE_NAME.to_s]
  end

  describe 'the cookie is bound to the instructeur it was issued for' do
    before do
      sign_in_with(instructeur.user)
      get sign_in_by_link_path(instructeur.id, jeton: token)
      sign_out!
    end

    it 'trusts the browser for the instructeur it was issued for' do
      sign_in_with(instructeur.user)

      get instructeur_procedures_path

      expect(response).to have_http_status(:ok)
    end

    it 'still asks another instructeur signing in from the same browser for an email link' do
      expect(trusted_device_cookie).to be_present

      sign_in_with(other_instructeur.user)
      get instructeur_procedures_path

      expect(response).to redirect_to(%r{/lien-envoye})
    end
  end

  describe 'following the link while signed out' do
    before { get sign_in_by_link_path(instructeur.id, jeton: token) }

    it 'does not trust the browser before anybody authenticates' do
      expect(trusted_device_cookie).to be_blank
    end

    it 'does not trust the browser for an unrelated account signing in afterwards' do
      sign_in_with(other_instructeur.user)

      get instructeur_procedures_path

      expect(response).to redirect_to(%r{/lien-envoye})
    end

    it 'trusts the browser once the matching instructeur signs in' do
      sign_in_with(instructeur.user)

      get instructeur_procedures_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'a cookie issued before the instructeur id was stored' do
    # Non zero microseconds on purpose: the cookie only keeps whole seconds, so this is
    # what forces the token lookup to be a range rather than an equality.
    let(:issued_at) { 2.days.ago.change(usec: 123456) }

    # Replays the implementation of trust_device that wrote the cookies we now have to
    # migrate: a payload carrying the timestamp and nothing else.
    def issue_legacy_cookie_for(instructeur, token)
      TrustedDeviceToken.find_by!(token:).update!(created_at: issued_at)

      allow_any_instance_of(Users::SessionsController)
        .to receive(:trust_device) do |controller, start_at, _instructeur, trusted_device_token|
          controller.send(:cookies).encrypted[TrustedDeviceConcern::TRUSTED_DEVICE_COOKIE_NAME] = {
            value: JSON.generate({ created_at: start_at }),
            expires: start_at + TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD,
            httponly: true,
          }
          trusted_device_token&.update(activated_at: start_at)
        end

      sign_in_with(instructeur.user)
      get sign_in_by_link_path(instructeur.id, jeton: token)
      sign_out!
    end

    before { issue_legacy_cookie_for(instructeur, token) }

    it 'trusts the browser again for the instructeur it was issued for' do
      sign_in_with(instructeur.user)

      get instructeur_procedures_path

      expect(response).to have_http_status(:ok)
    end

    it 'rewrites the cookie so that the decision no longer depends on the token' do
      sign_in_with(instructeur.user)
      get instructeur_procedures_path

      instructeur.trusted_device_tokens.destroy_all

      get instructeur_procedures_path

      expect(response).to have_http_status(:ok)
    end

    it 'still asks another instructeur signing in from the same browser for an email link' do
      sign_in_with(other_instructeur.user)

      get instructeur_procedures_path

      expect(response).to redirect_to(%r{/lien-envoye})
    end

    it 'asks for an email link when no token can vouch for the cookie' do
      instructeur.trusted_device_tokens.destroy_all

      sign_in_with(instructeur.user)
      get instructeur_procedures_path

      expect(response).to redirect_to(%r{/lien-envoye})
    end
  end

  # The reset link proves the instructeur controls the mailbox, which is what
  # this second factor asks for. Without a re-issue they would get a second link
  # to prove what the first just proved.
  describe 'resetting the password keeps the browser trusted' do
    let(:new_password) { '{An0ther-$3cure-p4ssWord}' }

    before do
      sign_in_with(instructeur.user)
      get sign_in_by_link_path(instructeur.id, jeton: token)
      sign_out!
    end

    def reset_password!
      raw_token = instructeur.user.send_reset_password_instructions

      put user_password_path, params: {
        user: {
          reset_password_token: raw_token,
          password: new_password,
          password_confirmation: new_password,
        },
      }
    end

    it 'does not ask for a second email link' do
      reset_password!

      get instructeur_procedures_path

      expect(response).to have_http_status(:ok)
    end

    # A cookie carrying the pre-reset counter would read as revoked at once.
    it 'issues a cookie the revocation cannot already have invalidated' do
      reset_password!

      expect(trusted_device_cookie).to be_present

      get instructeur_procedures_path
      expect(response).to have_http_status(:ok)
    end

    it 'still closes the other devices' do
      expect { reset_password! }
        .to change { instructeur.user.reload.trusted_device_version }
    end
  end
end
