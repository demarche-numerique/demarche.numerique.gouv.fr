# frozen_string_literal: true

describe Users::ConfirmationsController, type: :controller do
  let!(:user) { create(:user, :unconfirmed) }
  let(:confirmation_token) { user.confirmation_token }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe '#show' do
    context 'when confirming within the auto-sign-in delay' do
      before do
        travel_to(1.hour.from_now) {
          get :show, params: { confirmation_token: confirmation_token }
        }
      end

      it 'confirms the user' do
        expect(user.reload).to be_confirmed
      end

      it 'signs in the user after confirming its token' do
        expect(controller.current_user).to eq(user)
        expect(controller.current_instructeur).to be(nil)
        expect(controller.current_administrateur).to be(nil)
      end

      it 'redirects the user to the root page' do
        # NB: the root page may redirect the user again to the stored procedure path
        expect(controller).to redirect_to(root_path)
      end
    end

    context 'when the auto-sign-in delay has expired' do
      before do
        travel_to(3.hours.from_now) {
          get :show, params: { confirmation_token: confirmation_token }
        }
      end

      it 'confirms the user' do
        expect(user.reload).to be_confirmed
      end

      it 'doesn’t sign in the user' do
        expect(subject.current_user).to be(nil)
        expect(subject.current_instructeur).to be(nil)
        expect(subject.current_administrateur).to be(nil)
      end

      it 'redirects the user to the sign-in path' do
        expect(subject).to redirect_to(new_user_session_path)
      end
    end

    context 'when account was already confirmed long time ago' do
      let!(:user) { create(:user, confirmed_at: 3.hours.ago, confirmation_sent_at: 4.hours.ago, confirmation_token: "mytoken") }
      render_views

      subject do
        get :show, params: { confirmation_token: confirmation_token }
      end

      it 'redirect and does not expose the email' do
        expect(user).to be_confirmed
        expect(subject).to redirect_to(new_user_session_path)
        expect(subject.body).not_to include(user.email)
        expect(flash.notice).to include("Votre compte a déjà été activé")
      end
    end

    context 'when the confirmation link is replayed within the auto-sign-in delay after the account was already confirmed' do
      let!(:user) { create(:user, confirmed_at: 30.minutes.ago, confirmation_sent_at: 30.minutes.ago, confirmation_token: "mytoken") }

      subject do
        get :show, params: { confirmation_token: confirmation_token }
      end

      it 'does not sign the user in' do
        expect(user).to be_confirmed
        subject
        expect(controller.current_user).to be_nil
        expect(controller.current_instructeur).to be_nil
        expect(controller.current_administrateur).to be_nil
      end

      it 'redirects to the sign-in path' do
        expect(subject).to redirect_to(new_user_session_path)
      end
    end
  end

  describe '#new' do
    let(:email) { 'test@example.com' }
    render_views

    it 'decodes the signed email and makes it available to the view' do
      signed_email = controller.message_encryptor_service.encrypt_and_sign(email, purpose: :email_confirmation)

      get :new, params: { email: signed_email }

      expect(response.body).to have_text("votre adresse électronique #{email}.")
      expect(response.body).to have_text("nous pouvons vous le renvoyer")
    end

    context 'when signed email is invalid' do
      it 'does not fail' do
        get :new, params: { email: 'invalid_token' }

        expect(response.body).to have_text("cliquez sur le lien d’activation")
        expect(response.body).not_to have_text("nous pouvons vous le renvoyer")
      end
    end

    context 'without email parameter (transition from legacy confirmation flow)' do
      it 'does not fail' do
        get :new

        expect(response.body).to have_text("cliquez sur le lien d’activation")
        expect(response.body).not_to have_text("nous pouvons vous le renvoyer")
      end
    end
  end
end
