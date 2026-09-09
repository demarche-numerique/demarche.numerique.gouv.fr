# frozen_string_literal: true

describe Users::ProfilController, type: :controller do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  before { sign_in(user) }

  describe '#nav_bar_profile' do
    subject(:show_request) { get :show, params: params }
    let(:params) { {} }

    context 'with explicit ?context=instructeur' do
      let!(:user) { create(:instructeur).user }
      let(:params) { { context: 'instructeur' } }

      it 'returns :instructeur' do
        show_request
        expect(controller.nav_bar_profile).to eq(:instructeur)
      end
    end

    context 'with explicit ?context=invalid' do
      let(:params) { { context: 'pirate' } }

      it 'falls back to :user' do
        show_request
        expect(controller.nav_bar_profile).to eq(:user)
      end
    end

    context 'without context, multi-role admin user' do
      let!(:user) { create(:administrateur).user }

      it 'falls back to :administrateur (predominant role)' do
        show_request
        expect(controller.nav_bar_profile).to eq(:administrateur)
      end
    end

    context 'without context, simple user' do
      it 'returns :user' do
        show_request
        expect(controller.nav_bar_profile).to eq(:user)
      end
    end
  end

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
    shared_examples 'rejects the email change' do
      it 'rejects the email change' do
        expect(user.unconfirmed_email).to be_nil
        expect(response).to redirect_to(profil_path)
        expect(flash.alert).to include('contactez le support')
      end
    end

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
      let(:instructeur_email) { 'agent@interieur.gouv.fr' }
      let!(:user) { create(:instructeur, email: instructeur_email).user }

      before do
        patch :update_email, params: { user: { email: requested_email } }
        user.reload
      end

      context 'when the requested email has the same domain' do
        let(:requested_email) { 'other@interieur.gouv.fr' }

        it do
          expect(user.unconfirmed_email).to eq('other@interieur.gouv.fr')
          expect(response).to redirect_to(profil_path)
          expect(flash.notice).to eq(I18n.t('devise.registrations.update_needs_confirmation'))
        end
      end

      context 'when the requested email has the same domain with different case' do
        let(:requested_email) { 'Other@INTERIEUR.gouv.fr' }

        it do
          expect(user.unconfirmed_email).to eq('other@interieur.gouv.fr')
          expect(response).to redirect_to(profil_path)
          expect(flash.notice).to eq(I18n.t('devise.registrations.update_needs_confirmation'))
        end
      end

      context 'when the requested email has a different domain' do
        let(:requested_email) { 'agent@finances.gouv.fr' }

        it_behaves_like 'rejects the email change'
      end

      context 'when the requested email adds a subdomain' do
        let(:requested_email) { 'agent@sg.interieur.gouv.fr' }

        it_behaves_like 'rejects the email change'
      end

      context 'when the requested email tries a boundary attack' do
        let(:requested_email) { 'agent@interieur.gouv.fr.evil.com' }

        it_behaves_like 'rejects the email change'
      end
    end

    context 'when the user has an administrateur role but no instructeur role' do
      let(:administrateur_email) { 'admin@interieur.gouv.fr' }
      let!(:user) { create(:administrateur, email: administrateur_email, instructeur: nil).user }

      before do
        patch :update_email, params: { user: { email: requested_email } }
        user.reload
      end

      context 'when the requested email has the same domain' do
        let(:requested_email) { 'admin2@interieur.gouv.fr' }

        it do
          expect(user.unconfirmed_email).to eq('admin2@interieur.gouv.fr')
          expect(response).to redirect_to(profil_path)
          expect(flash.notice).to eq(I18n.t('devise.registrations.update_needs_confirmation'))
        end
      end

      context 'when the requested email has a different domain' do
        let(:requested_email) { 'admin@finances.gouv.fr' }

        it_behaves_like 'rejects the email change'
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

    context 'when the fci does not exist (already deleted or unknown id)' do
      subject { delete :destroy_fci, params: { fci_id: 'unknown' } }

      it 'redirects without raising' do
        expect { subject }.not_to raise_error
        expect(response).to redirect_to(profil_path)
      end
    end

    context 'when the user is logged in with FranceConnect' do
      before do
        allow(FranceConnectConfig).to receive(:client_config).and_return({ end_session_endpoint: 'https://logout.franceconnect.gouv.fr' })
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

  describe 'session revocation' do
    let(:other_user) { create(:user) }
    let!(:current_session) { user.open_user_session!('Chrome') }
    let!(:other_session) { user.open_user_session!('Firefox') }

    # The Warden session is seeded rather than `Current` stubbed: `Current` is
    # reset by the executor at the start of each request, and with the registry
    # open the fetch hook rejects a session that carries no row id. Seeding the
    # key exercises the real path -- the hook reads it and publishes it on
    # `Current`, exactly as it does in production.
    before do
      Flipper.enable_actor(:session_registry, user)
      session['warden.user.user.session'] = { SessionRegistrableConcern::SESSION_KEY => current_session.id }
    end

    describe '#revoke_session' do
      # First, and non negotiable: the id comes from the URL, so the only thing
      # standing between someone and another account's session is this scope.
      it 'answers 404 for a session of another account, and leaves it alone' do
        someone_elses = other_user.open_user_session!('Chrome')

        delete :revoke_session, params: { id: someone_elses.id }

        expect(response).to have_http_status(:not_found)
        expect(someone_elses.reload).not_to be_unusable
      end

      it 'answers 404 for an unknown id' do
        delete :revoke_session, params: { id: SecureRandom.uuid }

        expect(response).to have_http_status(:not_found)
      end

      # `revoke_sessions!` rotates the remember token before it touches any row,
      # so acting on a row that is already dead closes nothing but still cuts
      # remember-me on every device. A profile page left open while the session
      # died elsewhere would have done exactly that.
      it 'answers 404 for a row that is already revoked, and spares the remember token' do
        other_session.update!(revoked_at: Time.current, revoked_reason: 'logout_device')
        user.update_column(:remember_token, 'still-good')

        delete :revoke_session, params: { id: other_session.id }

        expect(response).to have_http_status(:not_found)
        expect(user.reload.remember_token).to eq('still-good')
      end

      it 'revokes the one it is given, and only that one' do
        delete :revoke_session, params: { id: other_session.id }

        expect(other_session.reload.unusable_reason).to eq(:logout_device)
        expect(current_session.reload).not_to be_unusable
        expect(response).to redirect_to(profil_path)
      end

      # Closing the session you are browsing with is a sign out, so there is no
      # profile page to come back to -- the redirect would only be rejected by
      # the fetch hook and land on the sign in page with an alert.
      it 'lets someone close the session they are browsing with, and sends them home' do
        delete :revoke_session, params: { id: current_session.id }

        expect(current_session.reload.unusable_reason).to eq(:logout_device)
        expect(response).to redirect_to(root_path)
      end

      # A remember-me cookie reopens a session on its own, so a revocation that
      # left it alive would be a lie -- and the card says, in as many words,
      # that closing a device cancels "se souvenir de moi" everywhere.
      it 'rotates the remember token, so no remember-me cookie survives' do
        user.update_column(:remember_token, 'a-stolen-token')

        delete :revoke_session, params: { id: other_session.id }

        expect(user.reload.remember_token).not_to eq('a-stolen-token')
      end
    end

    # Rows outlive a rollback of the flag. While it is off nothing enforces
    # them, so acting on them would report something that did not happen -- and
    # `Current` carries no session id, so sparing the current one is impossible.
    describe 'with the registry closed for the account' do
      before { Flipper.disable_actor(:session_registry, user) }

      it 'refuses to revoke one session' do
        delete :revoke_session, params: { id: other_session.id }

        expect(response).to have_http_status(:not_found)
        expect(other_session.reload).not_to be_unusable
      end

      it 'refuses to revoke them all, rather than close the current one' do
        delete :revoke_all_sessions

        expect(response).to have_http_status(:not_found)
        expect(current_session.reload).not_to be_unusable
        expect(other_session.reload).not_to be_unusable
      end
    end

    describe '#revoke_all_sessions' do
      # Every session, this one included. Sparing it would leave the browser
      # signed in while the account-wide trusted device bump treats it as
      # untrusted: signed in, and stuck on the next sensitive page.
      it 'revokes every session of the account, the current one included' do
        delete :revoke_all_sessions

        expect(other_session.reload.unusable_reason).to eq(:logout_all)
        expect(current_session.reload.unusable_reason).to eq(:logout_all)
        expect(response).to redirect_to(root_path)
      end

      it 'leaves other accounts untouched' do
        someone_elses = other_user.open_user_session!('Chrome')

        delete :revoke_all_sessions

        expect(someone_elses.reload).not_to be_unusable
      end
    end
  end
end
