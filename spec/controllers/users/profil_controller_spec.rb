# frozen_string_literal: true

describe Users::ProfilController, type: :controller do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  before { sign_in(user) }

  describe 'GET #show' do
    render_views

    before { post :show }

    context 'when the current user is not an instructeur' do
      it { expect(response.body).to include(I18n.t('users.profil.show.transfer_title')) }

      context 'when an existing transfer exists' do
        let(:dossiers) { Array.new(3) { create(:dossier, user: user) } }
        let(:next_owner) { 'loulou@lou.com' }
        let!(:transfer) { DossierTransfer.initiate(next_owner, dossiers) }

        before { post :show }

        it { expect(response.body).to include(I18n.t('users.profil.show.one_waiting_transfer', count: dossiers.count, email: next_owner)) }
      end
    end

    context 'when the current user is an instructeur' do
      let(:user) { create(:instructeur).user }

      it { expect(response.body).not_to include(I18n.t('users.profil.show.transfer_title')) }
    end
  end

  describe 'PATCH #update_email' do
    context 'when email is same as user' do
      it 'fails' do
        patch :update_email, params: { user: { email: user.email } }
        expect(response).to have_http_status(302)
        expect(flash[:alert]).to eq(["Le champ « La nouvelle adresse électronique » ne peut être identique à l’ancienne. Saisir une autre adresse électronique"])
      end
    end

    context 'when everything is fine' do
      let(:previous_request) { create(:user) }

      before do
        user.update(requested_merge_into: previous_request)
        patch :update_email, params: { user: { email: 'loulou@lou.com' } }
        user.reload
      end

      it do
        expect(user.unconfirmed_email).to eq('loulou@lou.com')
        expect(user.requested_merge_into).to be_nil
        expect(response).to redirect_to(profil_path)
        expect(flash.notice).to eq(I18n.t('devise.registrations.update_needs_confirmation'))
      end
    end

    context 'when the mail is already taken' do
      let(:existing_user) { create(:user) }

      before do
        user.update(unconfirmed_email: 'unconfirmed@mail.com')

        expect(UserMailer).to receive(:ask_for_merge).with(user, existing_user.email).and_return(double(deliver_later: true))

        perform_enqueued_jobs do
          patch :update_email, params: { user: { email: existing_user.email } }
        end
        user.reload
      end

      it 'launches the merge process' do
        expect(user.unconfirmed_email).to be_nil
        expect(response).to redirect_to(profil_path)
        expect(flash.notice).to eq(I18n.t('devise.registrations.update_needs_confirmation'))
      end
    end

    context 'when the mail is incorrect' do
      before do
        patch :update_email, params: { user: { email: 'incorrect' } }
        user.reload
      end

      it do
        expect(response).to redirect_to(profil_path)
        expect(flash.alert).to eq(["Le champ « Adresse électronique » est invalide. Saisissez une adresse électronique valide. Exemple : adresse@mail.com"])
      end
    end

    context 'when the user has an instructeur role' do
      let(:instructeur_email) { 'instructeur_email@a.com' }
      let!(:user) { create(:instructeur, email: instructeur_email).user }

      before do
        patch :update_email, params: { user: { email: requested_email } }
        user.reload
      end

      context 'when the requested email is allowed' do
        let(:requested_email) { 'legit@gouv.fr' }

        it do
          expect(user.unconfirmed_email).to eq('legit@gouv.fr')
          expect(response).to redirect_to(profil_path)
          expect(flash.notice).to eq(I18n.t('devise.registrations.update_needs_confirmation'))
        end
      end

      context 'when the requested email is not allowed' do
        let(:requested_email) { 'weird@gmail.com' }

        it do
          expect(response).to redirect_to(profil_path)
          expect(flash.alert).to include('contactez le support')
        end
      end

      context 'when the requested email is on a domain that only matches a legit suffix without an `@` boundary' do
        let(:requested_email) { 'admin@evilgouv.fr' }

        it 'rejects the email change' do
          expect(user.unconfirmed_email).to be_nil
          expect(response).to redirect_to(profil_path)
          expect(flash.alert).to include('contactez le support')
        end
      end
    end

    context 'when the user has an administrateur role but no instructeur role' do
      let(:administrateur_email) { 'administrateur_email@a.com' }
      let!(:user) { create(:administrateur, email: administrateur_email, instructeur: nil).user }

      before do
        patch :update_email, params: { user: { email: requested_email } }
        user.reload
      end

      context 'when the requested email is allowed' do
        let(:requested_email) { 'legit@gouv.fr' }

        it do
          expect(user.unconfirmed_email).to eq('legit@gouv.fr')
          expect(response).to redirect_to(profil_path)
          expect(flash.notice).to eq(I18n.t('devise.registrations.update_needs_confirmation'))
        end
      end

      context 'when the requested email is not allowed' do
        let(:requested_email) { 'weird@gmail.com' }

        it do
          expect(user.unconfirmed_email).to be_nil
          expect(response).to redirect_to(profil_path)
          expect(flash.alert).to include('contactez le support')
        end
      end
    end
  end

  context 'POST #transfer_all_dossiers' do
    let!(:dossiers) { Array.new(3) { create(:dossier, user: user) } }
    let(:next_owner) { 'loulou@lou.com' }
    let(:created_transfer) { DossierTransfer.first }

    subject {
      post :transfer_all_dossiers, params: { next_owner: next_owner }
    }

    before { subject }

    it "transfer all dossiers" do
      expect(created_transfer.email).to eq(next_owner)
      expect(created_transfer.dossiers).to match_array(dossiers)
      expect(flash.notice).to eq("Le transfert de 3 dossiers à #{next_owner} est en cours")
    end

    context "next owner has an empty email" do
      let(:next_owner) { '' }

      it "should not transfer to an empty email" do
        expect { subject }.not_to change { DossierTransfer.count }
        expect(flash.alert).to eq(["L’adresse électronique doit être rempli"])
      end
    end
  end

  context 'POST #accept_merge' do
    let!(:requesting_user) { create(:user, requested_merge_into: user) }

    subject { post :accept_merge }

    it 'merges the account' do
      expect_any_instance_of(User).to receive(:merge)

      subject
      requesting_user.reload

      expect(requesting_user.requested_merge_into).to be_nil
      expect(flash.notice).to include('Vous avez absorbé')
      expect(response).to redirect_to(profil_path)
    end
  end

  context 'POST #refuse_merge' do
    let!(:requesting_user) { create(:user, requested_merge_into: user) }

    subject { post :refuse_merge }

    it 'merges the account' do
      expect_any_instance_of(User).not_to receive(:merge)

      subject
      requesting_user.reload

      expect(requesting_user.requested_merge_into).to be_nil
      expect(flash.notice).to include('La fusion a été refusé')
      expect(response).to redirect_to(profil_path)
    end
  end

  context 'DELETE #destroy_fci' do
    let!(:fci) { create(:france_connect_information, user: user) }

    subject { delete :destroy_fci, params: { fci_id: fci.id } }

    it do
      expect(FranceConnectInformation.where(user: user).count).to eq(1)
      subject
      expect(FranceConnectInformation.where(user: user).count).to eq(0)
      expect(response).to redirect_to(profil_path)
    end

    context 'when the user is logged in with FranceConnect' do
      before do
        stub_const('FRANCE_CONNECT', { end_session_endpoint: 'https://logout.franceconnect.gouv.fr' })
        cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME] = 'id_token'
        cookies.encrypted[FranceConnectController::STATE_COOKIE_NAME] = 'state'
      end

      it 'deletes the cookies and redirect to FranceConnect logout' do
        subject
        expect(FranceConnectInformation.where(user: user).count).to eq(0)

        [
          FranceConnectController::ID_TOKEN_COOKIE_NAME,
          FranceConnectController::STATE_COOKIE_NAME,
        ].map(&:to_s).each do |cookie_name|
          expect(response.cookies.keys).to include(cookie_name)
          expect(response.cookies[cookie_name]).to be_nil
        end

        expect(response).to redirect_to('https://logout.franceconnect.gouv.fr?id_token_hint=id_token&post_logout_redirect_uri=http%3A%2F%2Ftest.host%2Fprofil&state=state')
      end
    end
  end
end
