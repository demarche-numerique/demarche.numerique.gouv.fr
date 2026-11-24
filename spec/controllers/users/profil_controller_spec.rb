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

    it { expect(response.body).to include(I18n.t('users.profil.show.change_password')) }
  end

  describe 'GET #show for an administrateur sharing a procedure with another one' do
    render_views

    let(:user) { administrateurs.blank.user }

    before do
      procedures.individual.administrateurs << administrateurs.blank
      APIToken.generate(administrateurs.default, name: 'Jeton du collègue')
      get :show
    end

    it 'lists the api tokens of the other administrateur in a table' do
      shared_tokens = response.parsed_body.at_css('table[aria-labelledby="shared-api-tokens-title"]')
      expect(response.parsed_body.at_css('#shared-api-tokens-title').text.strip).to eq('Jetons d’autres administrateurs sur vos démarches')
      expect(shared_tokens.at_css('tbody th').text).to include('Jeton du collègue', "Géré par #{administrateurs.default.email}")
    end
  end

  describe 'GET #show for an administrateur and their api tokens' do
    render_views

    let(:administrateur) { administrateurs.blank }
    let(:user) { administrateur.user }
    let(:card) { response.parsed_body.at_css("##{ActionView::RecordIdentifier.dom_id(administrateur, :profil_api_token)}") }
    let(:expired_button) { card.at_css('#expired-api-tokens .fr-accordion__btn') }

    it 'only offers to create a token when there is none' do
      get :show
      expect(card.at_css('a.fr-btn').text.strip).to eq('Créer un nouveau jeton')
      expect(card.at_css('table')).to be_nil
    end

    it 'lists my valid tokens, and folds the expired ones away' do
      APIToken.generate(administrateur, name: 'Jeton valide')
      APIToken.generate(administrateur, name: 'Jeton expiré').first.update_column(:expires_at, 1.day.ago.to_date)
      get :show

      expect(card.at_css('table[aria-labelledby="my-api-tokens-title"] tbody th').text).to include('Jeton valide')
      expect(expired_button.text.strip).to eq('Jetons expirés (1)')
      expect(expired_button['aria-expanded']).to eq('false')
      expect(card.at_css('#expired-api-tokens table tbody th').text).to include('Jeton expiré')
    end

    it 'unfolds the expired tokens when no token is valid' do
      APIToken.generate(administrateur, name: 'Jeton expiré').first.update_column(:expires_at, 1.day.ago.to_date)
      get :show

      expect(card.at_css('table[aria-labelledby="my-api-tokens-title"]')).to be_nil
      expect(expired_button['aria-expanded']).to eq('true')
      expect(card.at_css('#expired-api-tokens-content')['class']).to include('fr-collapse--expanded')
    end
  end

  describe 'GET #show when ProConnect is required for the administrateur' do
    render_views

    let(:user) { administrateurs.default.user }

    before do
      allow(ProConnectService).to receive(:enabled?).and_return(true)
      user.administrateur.update!(pro_connect_required_at: Time.zone.now)
      get :show
    end

    it 'hides the password card' do
      expect(response.body).not_to include(I18n.t('users.profil.show.change_password'))
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

    context 'when the account has dossiers on a procedure that requires FranceConnect+' do
      let(:existing_user) { create(:user) }

      before do
        create(:dossier, :en_construction, user:, procedure: create(:procedure, :published, france_connect_plus_required: true))
      end

      it 'refuses the merge from a session opened another way' do
        sign_in(user, login_method: :password)

        patch :update_email, params: { user: { email: existing_user.email } }

        expect(user.reload.requested_merge_into).to be_nil
        expect(flash.alert).to include('connectez-vous avec FranceConnect+')
      end

      it 'refuses the merge from a FranceConnect+ session of another identity, saying so' do
        user.dossiers.update_all(france_connect_plus_sub: 'owner_sub')
        fci = create(:france_connect_information, user:, france_connect_particulier_id: 'another_sub')
        sign_in(user, login_method: :france_connect_plus, france_connect_information: fci)

        patch :update_email, params: { user: { email: existing_user.email } }

        expect(user.reload.requested_merge_into).to be_nil
        expect(flash.alert).to include('dossiers liés à une autre identité FranceConnect+')
      end

      it 'asks for the merge from a FranceConnect+ session' do
        sign_in(user, login_method: :france_connect_plus)

        patch :update_email, params: { user: { email: existing_user.email } }

        expect(user.reload.requested_merge_into).to eq(existing_user)
      end
    end

    describe 'warning the current address' do
      let(:previous_email) { user.email }

      it 'warns it when a new address is requested' do
        expect { patch :update_email, params: { user: { email: 'loulou@lou.com' } } }
          .to have_enqueued_mail(DeviseUserMailer, :email_changed).with(user, { to: previous_email })
      end

      it 'warns it when a merge is requested' do
        existing_user = create(:user)

        expect { patch :update_email, params: { user: { email: existing_user.email } } }
          .to have_enqueued_mail(DeviseUserMailer, :email_changed).with(user, { to: previous_email })
      end

      it 'does not warn it when the change is rejected' do
        expect { patch :update_email, params: { user: { email: 'incorrect' } } }
          .not_to have_enqueued_mail(DeviseUserMailer, :email_changed)
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
    let(:france_connect_information) { nil }
    let(:login_method) { :password }

    subject {
      post :transfer_all_dossiers, params: { next_owner: next_owner }
    }

    before do
      sign_in(user, login_method:, france_connect_information:)
      subject
    end

    it "transfer all dossiers" do
      expect(created_transfer.email).to eq(next_owner)
      expect(created_transfer.dossiers).to match_array(dossiers)
      expect(flash.notice).to eq("Le transfert de 3 dossiers à #{next_owner} est en cours")
    end

    context 'with a dossier of a procedure that requires FranceConnect+' do
      let(:france_connect_plus_procedure) { create(:procedure, :published, france_connect_plus_required: true) }
      let!(:dossiers) do
        [
          create(:dossier, user:),
          create(:dossier, user:, procedure: france_connect_plus_procedure, france_connect_plus_sub: 'owner_sub'),
        ]
      end

      it 'leaves it out from a session opened another way, with a link to sign in with FranceConnect+' do
        expect(created_transfer.dossiers).to eq([dossiers.first])
        expect(flash.notice).to eq("Le transfert d’un dossier à #{next_owner} est en cours")
        expect(flash.alert).to eq("Un dossier n’a pas été transféré : sa démarche exige FranceConnect+. <a href='/france_connect_plus'>Connectez-vous avec FranceConnect+</a> pour le transférer.")
        expect(controller.stored_location_for(:user)).to eq(profil_path)
      end

      context 'from a FranceConnect+ session of another identity' do
        let(:login_method) { :france_connect_plus }
        let(:france_connect_information) { create(:france_connect_information, user:, france_connect_particulier_id: 'another_sub') }

        it 'leaves it out, saying it is bound to another identity' do
          expect(created_transfer.dossiers).to eq([dossiers.first])
          expect(flash.alert).to eq("Un dossier n’a pas été transféré : il est lié à une autre identité FranceConnect+ que celle avec laquelle vous êtes connecté.")
        end
      end

      context 'and no other dossier' do
        let!(:dossiers) { Array.new(2) { create(:dossier, user:, procedure: france_connect_plus_procedure) } }

        it 'starts no transfer' do
          expect(created_transfer).to be_nil
          expect(flash.notice).to be_nil
          expect(flash.alert).to eq("2 dossiers n’ont pas été transférés : leur démarche exige FranceConnect+. <a href='/france_connect_plus'>Connectez-vous avec FranceConnect+</a> pour les transférer.")
        end
      end

      context 'and an empty email' do
        let(:next_owner) { '' }

        it 'says both' do
          expect(flash.alert).to eq([
            "Un dossier n’a pas été transféré : sa démarche exige FranceConnect+. <a href='/france_connect_plus'>Connectez-vous avec FranceConnect+</a> pour le transférer.",
            "L’adresse électronique doit être rempli",
          ])
        end
      end
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

    context 'with a FranceConnect+ session, and one older than login methods, on other devices' do
      let!(:other_device) { user.open_user_session!('other device', login_method: :france_connect_plus) }
      let!(:legacy_device) { user.open_user_session!('legacy device') }

      context 'from a session opened with FranceConnect' do
        before { sign_in(user, login_method: :france_connect) }

        it 'signs the other devices out, and goes on as a password session with the same start and deadline' do
          opened_with_france_connect = user.user_sessions.find_by!(login_method: :france_connect)
          opened_with_france_connect.update!(created_at: 3.weeks.ago, expires_at: 3.days.from_now)

          expect { subject }.not_to change { user.reload.sign_in_count }

          expect(other_device.reload.revoked_reason).to eq('france_connect_unlinked')
          expect(legacy_device.reload.revoked_reason).to eq('france_connect_unlinked')
          expect(opened_with_france_connect.reload.revoked_reason).to eq('france_connect_unlinked')

          replacing = user.user_sessions.usable.find_by!(login_method: :password)
          expect(replacing.created_at).to eq(opened_with_france_connect.created_at)
          expect(replacing.expires_at).to eq(opened_with_france_connect.expires_at)
          expect(session['warden.user.user.session'][SessionRegistrableConcern::SESSION_KEY]).to eq(replacing.id)
        end

        it 'keeps the session as it was when the identity cannot be destroyed' do
          allow_any_instance_of(FranceConnectInformation).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)

          expect { subject }.to raise_error(ActiveRecord::RecordNotDestroyed)
          expect(user.user_sessions.usable.pluck(:login_method)).to include('france_connect')
          expect(user.user_sessions.where(login_method: :password)).to be_empty
        end
      end

      context 'from a session opened with a password' do
        before { sign_in(user, login_method: :password) }

        it 'signs the other devices out, and keeps this one' do
          kept = user.user_sessions.find_by!(login_method: :password)

          subject

          expect(other_device.reload.revoked_reason).to eq('france_connect_unlinked')
          expect(legacy_device.reload.revoked_reason).to eq('france_connect_unlinked')
          expect(kept.reload.revoked_at).to be_nil
        end
      end
    end

    it 'keeps the rows of the sessions the identity opened' do
      user_session = user.user_sessions.create!(login_method: :france_connect, france_connect_information: fci, expires_at: 1.day.from_now)

      subject

      expect(user_session.reload).to have_attributes(france_connect_information_id: nil, revoked_reason: 'france_connect_unlinked')
    end

    context 'when the fci does not exist (already deleted or unknown id)' do
      subject { delete :destroy_fci, params: { fci_id: 'unknown' } }

      it 'redirects without raising' do
        expect { subject }.not_to raise_error
        expect(response).to redirect_to(profil_path)
      end
    end

    context 'when the user is logged in with FranceConnect' do
      let(:id_token) { JSON::JWT.new(sub: fci.france_connect_particulier_id).to_s }

      before do
        allow(FranceConnectConfig).to receive(:client_config).and_return({ end_session_endpoint: 'https://logout.franceconnect.gouv.fr' })
        cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME] = id_token
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

        expect(response).to redirect_to("https://logout.franceconnect.gouv.fr?id_token_hint=#{id_token}&post_logout_redirect_uri=http%3A%2F%2Ftest.host%2Fprofil&state=state")
      end
    end
  end
end
