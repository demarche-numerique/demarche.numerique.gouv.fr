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

    context 'when the user is an administrateur who must use ProConnect' do
      before do
        allow(ProConnectService).to receive(:enabled?).and_return(true)
        user.create_administrateur!(pro_connect_required_at: Time.zone.now)

        travel_to(1.hour.from_now) {
          get :show, params: { confirmation_token: confirmation_token }
        }
      end

      it 'confirms the account but sends to ProConnect instead of signing in' do
        expect(user.reload).to be_confirmed
        expect(controller.current_user).to be_nil
        expect(response).to redirect_to(pro_connect_path(force_pro_connect: true))
        expect(flash.alert).to eq('Vous devez utiliser ProConnect pour vous connecter à votre espace administrateur.')
      end
    end

    context 'when an administrateur confirms an email change while already signed in' do
      let!(:user) { create(:user) }

      before do
        allow(ProConnectService).to receive(:enabled?).and_return(true)
        user.create_administrateur!(pro_connect_required_at: Time.zone.now)
        sign_in(user)
        user.update!(email: 'nouvelle@example.com')

        get :show, params: { confirmation_token: user.confirmation_token }
      end

      it 'applies the email change without sending to ProConnect' do
        expect(user.reload.email).to eq('nouvelle@example.com')
        expect(response).to redirect_to(root_path)
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

    context 'when the address requested by an email change was taken in the meantime' do
      render_views

      let(:account) { create(:user) }

      before do
        freeze_time
        account.update_columns(unconfirmed_email: create(:user).email, confirmation_token: 'email-change-token', confirmation_sent_at: Time.current)
        session[:confirmation_requested_at] = 30.seconds.ago.to_i

        get :show, params: { confirmation_token: 'email-change-token' }
      end

      it 'shows the resend form with the remaining time' do
        expect(response.body).to have_button('Renvoyer un email de confirmation (90 secondes)', disabled: true)
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
      expect(response.body).to have_text("Pour activer votre compte, nous avons besoin de vérifier votre adresse électronique #{email}.")
      expect(response.body).to have_text('Ouvrez votre boîte email et cliquez sur le lien d’activation dans le message que vous avez reçu.')
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

    context 'with a confirmation request in the session' do
      let(:signed_email) { controller.message_encryptor_service.encrypt_and_sign(email, purpose: :email_confirmation) }

      before { freeze_time }

      it 'counts down from the last request' do
        session[:confirmation_requested_at] = 30.seconds.ago.to_i
        get :new, params: { email: signed_email }

        expect(response.body).to have_button('Renvoyer un email de confirmation (90 secondes)', disabled: true)
      end

      it 'lets them resend once two minutes have passed' do
        session[:confirmation_requested_at] = 3.minutes.ago.to_i
        get :new, params: { email: signed_email }

        expect(response.body).to have_button(exact_text: 'Renvoyer un email de confirmation', disabled: false)
      end

      it 'never waits more than two minutes when server clocks drift' do
        session[:confirmation_requested_at] = 10.seconds.from_now.to_i
        get :new, params: { email: signed_email }

        expect(response.body).to have_button('Renvoyer un email de confirmation (120 secondes)', disabled: true)
      end
    end

    it 'lets them resend right away without any request in the session' do
      get :new, params: { email: controller.message_encryptor_service.encrypt_and_sign(email, purpose: :email_confirmation) }

      expect(response.body).to have_button(exact_text: 'Renvoyer un email de confirmation', disabled: false)
    end

    it 'shows no button once the page address has expired, even after a recent request' do
      signed_email = controller.message_encryptor_service.encrypt_and_sign(email, purpose: :email_confirmation, expires_in: 1.hour)
      travel 2.hours
      session[:confirmation_requested_at] = 30.seconds.ago.to_i

      get :new, params: { email: signed_email }

      expect(response.body).not_to have_css('[data-controller="countdown-button"]')
      expect(response.body).not_to have_button('Renvoyer un email de confirmation')
    end
  end

  describe '#create' do
    let(:procedure) { procedures.individual }
    let(:stored_path) { commencer_path(path: procedure.path, prefill_token: 'prefill-token') }
    let(:submitted_email) { user.email }
    let(:signed_up_email) { user.email }

    subject { post :create, params: { user: { email: submitted_email } } }

    before do
      controller.store_location_for(:user, stored_path)
      session[:signed_up_email] = controller.message_encryptor_service.encrypt_and_sign(signed_up_email, purpose: :signed_up_email, expires_in: 1.hour)
      allow(DeviseUserMailer).to receive(:confirmation_instructions).and_return(double(deliver_later: true))
    end

    def expect_mailed_context(procedure_after_confirmation:, prefill_token:)
      expect(DeviseUserMailer).to have_received(:confirmation_instructions)
        .with(user, anything, hash_including(procedure_after_confirmation:, prefill_token:))
    end

    context 'when resending to the email that just signed up in this session' do
      it 'keeps the procedure and the prefill_token in the confirmation link' do
        subject
        expect_mailed_context(procedure_after_confirmation: procedure, prefill_token: 'prefill-token')
      end
    end

    context 'when the submitted email differs only by case and spacing' do
      let(:submitted_email) { " #{user.email.upcase} " }

      it 'keeps the prefill_token' do
        subject
        expect_mailed_context(procedure_after_confirmation: procedure, prefill_token: 'prefill-token')
      end
    end

    context 'when resending to another email' do
      let(:signed_up_email) { 'someone-else@example.com' }

      it 'keeps the procedure but does not inject the prefill_token' do
        subject
        expect_mailed_context(procedure_after_confirmation: procedure, prefill_token: nil)
      end
    end

    context 'when the sign up happened more than an hour ago' do
      it 'does not inject the prefill_token' do
        travel_to(2.hours.from_now) { subject }
        expect_mailed_context(procedure_after_confirmation: procedure, prefill_token: nil)
      end
    end

    context 'when the procedure stored in the session no longer exists' do
      let(:stored_path) { commencer_path(path: 'unknown-procedure', prefill_token: 'prefill-token') }

      it 'still resends the confirmation email, without any context' do
        subject

        expect_mailed_context(procedure_after_confirmation: nil, prefill_token: nil)
        expect(response).not_to redirect_to(root_path)
      end
    end

    it 'answers the same notice whether the address exists or not' do
      post :create, params: { user: { email: 'inconnue@example.com' } }

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to eq('Si votre adresse électronique existe dans notre base de données, vous recevrez sous quelques minutes un email avec des instructions pour activer votre compte.')
    end

    it 'remembers the request, even for an unknown address' do
      freeze_time

      post :create, params: { user: { email: 'inconnue@example.com' } }

      expect(session[:confirmation_requested_at]).to eq(Time.current.to_i)
    end
  end
end
