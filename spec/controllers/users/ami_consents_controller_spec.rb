# frozen_string_literal: true

RSpec.describe Users::AmiConsentsController, type: :controller do
  render_views

  let(:user) { users.usager }

  before do
    allow_any_instance_of(Ami::Client).to receive(:configured?).and_return(true)
    allow(Ami::RecipientFcHash).to receive(:call).and_return("abc123")
  end

  describe 'GET #show' do
    subject(:show) { get :show }

    context 'when the user is not signed in' do
      it { expect(show).to redirect_to(new_user_session_path) }
    end

    context 'when the user is signed in' do
      before { sign_in(user) }

      it 'renders the consent state in its turbo frame' do
        allow(Ami::ConsentStatus).to receive(:call).with(user).and_return(:granted)

        expect(show).to have_http_status(:ok)
        expect(response.body).to include('turbo-frame')
        expect(response.body).to include('Vous suivez vos démarches')
      end

      context 'when the user has no France Connect identity' do
        before { allow(Ami::RecipientFcHash).to receive(:call).and_return(nil) }

        it { expect(show).to have_http_status(:no_content) }
      end

      context 'when AMI is not configured' do
        before { allow_any_instance_of(Ami::Client).to receive(:configured?).and_return(false) }

        it { expect(show).to have_http_status(:no_content) }
      end
    end
  end

  describe 'POST #create' do
    subject(:create) { post :create }

    before { sign_in(user) }

    context 'when AMI accepts the consent' do
      before { allow(Ami::GrantConsent).to receive(:call).with(user).and_return(Dry::Monads::Success(nil)) }

      it 'confirms the follow-up and moves the focus to it' do
        expect(create).to have_http_status(:ok)
        expect(response.body).to include('Vous suivez vos démarches')
        expect(response.body).to include('autofocus')
      end
    end

    context 'when AMI is unreachable' do
      before do
        allow(Ami::GrantConsent).to receive(:call).with(user)
          .and_return(Dry::Monads::Failure(API::Client::Error[:timeout, 0, true, "Operation timed out"]))
      end

      it 'warns the user without failing, and keeps the consent available' do
        expect(create).to have_http_status(:ok)
        expect(response.body).to include('momentanément indisponible')
        expect(response.body).to include('Je souhaite suivre mes démarches')
      end
    end
  end
end
