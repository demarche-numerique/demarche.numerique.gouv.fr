# frozen_string_literal: true

RSpec.describe Users::AmiConsentsController, type: :controller do
  render_views

  let(:user) { users.usager }
  let(:dossier) { dossiers.en_construction }

  before do
    allow_any_instance_of(Ami::Client).to receive(:configured?).and_return(true)
    allow_any_instance_of(Procedure).to receive(:feature_enabled?).with(:ami_notifications).and_return(true)
    allow(Ami::RecipientFcHash).to receive(:call).and_return("abc123")
  end

  describe 'GET #show' do
    subject(:show) { get :show, params: { id: dossier.id } }

    context 'when the user is not signed in' do
      it { expect(show).to redirect_to(new_user_session_path) }
    end

    context 'when the user is signed in' do
      before { sign_in(user) }

      it 'renders the consent state in its turbo frame' do
        allow(Ami::ConsentStatus).to receive(:call).with("abc123").and_return(:granted)

        expect(show).to have_http_status(:ok)
        expect(response.body).to include('turbo-frame')
        expect(response.body).to include('Vous suivez vos démarches')
      end

      # Une réponse sans turbo-frame afficherait « Content missing » à la place
      # de l'encart : on répond toujours par le frame, vide le cas échéant.
      context 'when the user has no France Connect identity' do
        before { allow(Ami::RecipientFcHash).to receive(:call).and_return(nil) }

        it 'answers an empty frame' do
          expect(show).to have_http_status(:ok)
          expect(response.body).to include('turbo-frame')
          expect(response.body).not_to include('Je souhaite suivre mes démarches')
        end
      end

      context 'when AMI is not configured' do
        before { allow_any_instance_of(Ami::Client).to receive(:configured?).and_return(false) }

        it 'answers an empty frame' do
          expect(show).to have_http_status(:ok)
          expect(response.body).to include('turbo-frame')
          expect(response.body).not_to include('Je souhaite suivre mes démarches')
        end
      end

      # Sans le drapeau, l'événement serait écarté juste après : ne pas
      # promettre un suivi qui n'aura pas lieu.
      context 'when the procedure does not notify AMI' do
        before { allow_any_instance_of(Procedure).to receive(:feature_enabled?).with(:ami_notifications).and_return(false) }

        it 'answers an empty frame' do
          expect(show).to have_http_status(:ok)
          expect(response.body).not_to include('Je souhaite suivre mes démarches')
        end
      end

      context 'with a dossier belonging to someone else' do
        let(:dossier) { create(:dossier, :en_construction) }

        it { expect { show }.to raise_error(ActiveRecord::RecordNotFound) }
      end

      # Le consentement engage l'identité France Connect de celui qui clique :
      # un invité ne peut pas le donner depuis le dossier d'un autre.
      context 'with a dossier the user is only invited to' do
        let(:dossier) { create(:dossier, :en_construction) }

        before { create(:invite, dossier:, user:) }

        it { expect { show }.to raise_error(ActiveRecord::RecordNotFound) }
      end
    end
  end

  describe 'POST #create' do
    subject(:create_consent) { post :create, params: { id: dossier.id } }

    before do
      sign_in(user)
      allow(Ami::GrantConsent).to receive(:call).and_return(:granted)
    end

    it 'grants the consent from the dossier being viewed, reusing the hash it already has' do
      create_consent

      expect(Ami::GrantConsent).to have_received(:call).with(dossier:, fc_hash: "abc123")
    end

    it 'confirms the follow-up and moves the focus to it' do
      expect(create_consent).to have_http_status(:ok)
      expect(response.body).to include('Vous suivez vos démarches')
      expect(response.body).to include('autofocus')
    end

    context 'when AMI refused the consent' do
      before do
        allow(Ami::GrantConsent).to receive(:call).and_return(:error)
      end

      # Mieux vaut avouer l'échec que confirmer un suivi qui n'existe pas.
      it 'says the consent could not be saved and offers to try again' do
        expect(create_consent).to have_http_status(:ok)
        expect(response.body).not_to include('Vous suivez vos démarches')
        expect(response.body).to include('fr-error-text')
        expect(response.body).to include('Je souhaite suivre mes démarches')
      end
    end
  end
end
