# frozen_string_literal: true

describe 'Trusted device (second factor by email link)', type: :request do
  # Not the seeded instructeurs: they bypass the email login token, which is the
  # very step this file is about.
  let_it_be(:instructeur) { create(:instructeur, bypass_email_login_token: false, password: SECURE_PASSWORD) }
  let_it_be(:other_instructeur) { create(:instructeur, bypass_email_login_token: false, password: SECURE_PASSWORD) }

  let(:password) { SECURE_PASSWORD }
  let(:token) { instructeur.create_trusted_device_token }

  def sign_out!
    delete destroy_user_session_path
  end

  def trusted_device_cookie
    cookies[TrustedDeviceConcern::TRUSTED_DEVICE_COOKIE_NAME.to_s]
  end

  describe 'the cookie is bound to the instructeur it was issued for' do
    before do
      post_user_session(instructeur.user, password:)
      get sign_in_by_link_path(instructeur.id, jeton: token)
      sign_out!
    end

    it 'trusts the browser for the instructeur it was issued for' do
      post_user_session(instructeur.user, password:)

      get instructeur_procedures_path

      expect(response).to have_http_status(:ok)
    end

    it 'still asks another instructeur signing in from the same browser for an email link' do
      expect(trusted_device_cookie).to be_present

      post_user_session(other_instructeur.user, password:)
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
      post_user_session(other_instructeur.user, password:)

      get instructeur_procedures_path

      expect(response).to redirect_to(%r{/lien-envoye})
    end

    it 'trusts the browser once the matching instructeur signs in' do
      post_user_session(instructeur.user, password:)

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

      post_user_session(instructeur.user, password:)
      get sign_in_by_link_path(instructeur.id, jeton: token)
      sign_out!
    end

    before { issue_legacy_cookie_for(instructeur, token) }

    it 'trusts the browser again for the instructeur it was issued for' do
      post_user_session(instructeur.user, password:)

      get instructeur_procedures_path

      expect(response).to have_http_status(:ok)
    end

    it 'rewrites the cookie so that the decision no longer depends on the token' do
      post_user_session(instructeur.user, password:)
      get instructeur_procedures_path

      instructeur.trusted_device_tokens.destroy_all

      get instructeur_procedures_path

      expect(response).to have_http_status(:ok)
    end

    it 'still asks another instructeur signing in from the same browser for an email link' do
      post_user_session(other_instructeur.user, password:)

      get instructeur_procedures_path

      expect(response).to redirect_to(%r{/lien-envoye})
    end

    it 'asks for an email link when no token can vouch for the cookie' do
      instructeur.trusted_device_tokens.destroy_all

      post_user_session(instructeur.user, password:)
      get instructeur_procedures_path

      expect(response).to redirect_to(%r{/lien-envoye})
    end
  end

  # An expert invited on an avis sets their password from a link carrying a token
  # they received by email -- the very proof the second factor asks for.
  describe 'an expert signing up from an avis invitation' do
    let_it_be(:pending_avis, refind: true) { avis.pending }
    let_it_be(:expert_user, reload: true) { pending_avis.expert.user }
    let_it_be(:expert_instructeur, refind: true) { expert_user.instructeur || expert_user.create_instructeur! }

    let(:invited_at) { Time.current }
    let(:invitation_token) do
      travel_to(invited_at) { expert_user.invite_expert_and_send_avis!(pending_avis) }
      expert_user.confirmation_token
    end

    def sign_up(user_params)
      post sign_up_expert_avis_path(pending_avis.procedure, pending_avis),
        params: { email: expert_user.email, user: { confirmation_token: invitation_token }.merge(user_params) }
    end

    it 'trusts the browser instead of asking for a second link to the same mailbox' do
      sign_up(password:)

      expect(response).to redirect_to(expert_all_avis_path)
      expect(expert_user.reload.valid_password?(password)).to be true
      expect(trusted_device_cookie).to be_present

      follow_redirect!

      expect(response).to have_http_status(:ok)
    end

    it 'sends a sign up carrying no password back to the form, and trusts nothing' do
      sign_up({})

      expect(response).to redirect_to(sign_up_expert_avis_path(pending_avis.procedure, pending_avis, email: expert_user.email, confirmation_token: invitation_token))
      expect(trusted_device_cookie).to be_blank
    end

    context 'when the invitation was sent just under two days ago' do
      let(:invited_at) { 47.hours.ago }

      it 'still trusts the browser' do
        sign_up(password:)

        expect(trusted_device_cookie).to be_present
      end
    end

    context 'when the avis has been revoked' do
      before { pending_avis.update_column(:revoked_at, Time.current) }

      it 'signs the expert up, but trusts nothing' do
        sign_up(password:)

        expect(response).to redirect_to(expert_all_avis_path)
        expect(trusted_device_cookie).to be_blank
      end
    end

    context 'when the invitation was sent more than two days ago' do
      let(:invited_at) { 3.days.ago }

      it 'signs the expert up, but trusts nothing' do
        sign_up(password:)

        expect(response).to redirect_to(expert_all_avis_path)
        expect(trusted_device_cookie).to be_blank
      end
    end

    context 'when the expert is not an instructeur' do
      before { expert_instructeur.destroy! }

      it 'writes no trusted device cookie' do
        sign_up(password:)

        expect(response).to redirect_to(expert_all_avis_path)
        expect(trusted_device_cookie).to be_blank
      end
    end
  end

  # The reset link proves the instructeur controls the mailbox, which is what
  # this second factor asks for. Without a re-issue they would get a second link
  # to prove what the first just proved.
  describe 'resetting the password keeps the browser trusted' do
    let(:new_password) { '{An0ther-$3cure-p4ssWord}' }

    before do
      post_user_session(instructeur.user, password:)
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

    # The link clicked in `before` is under a week old, so the revocation took its
    # row: without a new one the job would let this cookie expire unannounced.
    it 'warns a week before the reissued cookie expires' do
      reset_password!
      expiring = -> { TrustedDeviceToken.expiring_in_one_week.where(instructeur:) }

      travel_to(20.days.from_now) { expect(expiring.call).not_to exist }
      travel_to(25.days.from_now) { expect(expiring.call).to exist }
    end

    # The token the reset activates was never sent: it must not hold back a link
    # asked for from another browser.
    it 'still sends a link asked for right after' do
      reset_password!
      reset! # another browser: no session, no trusted device cookie

      post_user_session(instructeur.user, password: new_password)

      expect { get instructeur_procedures_path }
        .to have_enqueued_mail(InstructeurMailer, :send_login_token)
    end

    it 'still closes the other devices' do
      expect { reset_password! }
        .to change { instructeur.user.reload.trusted_device_version }
    end
  end
end
