# frozen_string_literal: true

describe Users::SessionsController, type: :controller do
  let(:email) { 'unique@plop.com' }
  let(:password) { SECURE_PASSWORD }
  let(:loged_in_with_france_connect) { User.loged_in_with_france_connects.fetch(:particulier) }
  let!(:user) { create(:user, email: email, password: password, loged_in_with_france_connect: loged_in_with_france_connect) }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe '#create' do
    let(:user) { create(:user, email: email, password: password, loged_in_with_france_connect: 'particulier') }
    let(:send_password) { password }
    let(:remember_me) { '0' }

    before do
      cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME] = 'id_token'
      cookies.encrypted[FranceConnectController::STATE_COOKIE_NAME] = 'state'
    end

    subject do
      post :create, params: {
        user: {
          email: email,
          password: send_password,
          remember_me: remember_me,
        },
      }
    end

    context 'when the credentials are right' do
      it 'signs in' do
        expect { subject }.to change { user.reload.last_sign_in_at }

        expect(response).to redirect_to(root_path)
        expect(controller.current_user).to eq(user)
        expect(user.reload.loged_in_with_france_connect).to be(nil)
        expect(user.reload.remember_created_at).to be_nil

        [
          FranceConnectController::ID_TOKEN_COOKIE_NAME,
          FranceConnectController::STATE_COOKIE_NAME,
        ].map(&:to_s).each do |cookie_name|
          expect(response.cookies.keys).to include(cookie_name)
          expect(response.cookies[cookie_name]).to be_nil
        end
      end

      context 'when remember_me is specified' do
        let(:remember_me) { '1' }

        it 'remembers' do
          subject

          expect(user.reload.remember_created_at).to be_present
        end
      end

      context 'when a previous path was registered' do
        let(:stored_path) { '/a_path' }

        before { controller.store_location_for(:user, stored_path) }

        it 'redirects to that previous path' do
          subject

          expect(response).to redirect_to(stored_path)
        end
      end

      context 'when the user is locked' do
        before { user.lock_access! }

        it 'redirects to new_path' do
          subject

          expect(response).to render_template(:new)
          expect(flash.alert).to eq("Adresse électronique ou mot de passe incorrect.")
        end
      end

      context 'when user has not yet a preferred domain' do
        before do
          allow(Current).to receive(:host).and_return(ENV.fetch("APP_HOST"))
        end

        it 'update preferred domain' do
          subject

          expect(user.reload.preferred_domain_demarche_numerique_gouv_fr?).to be_truthy
        end
      end
    end

    context 'when the credentials are wrong' do
      let(:send_password) { 'wrong_password' }

      it 'fails to sign in with bad credentials' do
        subject

        expect(response).to render_template(:new)
        expect(controller.current_user).to be(nil)
      end
    end

    xcontext 'when email domain is in mandatory list' do
      let(:email) { 'user@beta.gouv.fr' }
      it 'redirects to pro connect with force parameter and is not logged in' do
        expect(ProConnectService).to receive(:enabled?).and_return(true)
        subject
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq("La connexion des agents passe à présent systématiquement par ProConnect")
        expect(controller.current_user).to be_nil
      end
    end
  end

  describe '#destroy' do
    let!(:user) { create(:user, email: email, password: password, loged_in_with_france_connect: loged_in_with_france_connect) }
    let!(:instructeur) { create(:instructeur, user: user, pro_connect_id_token:) }
    let(:pro_connect_id_token) { nil }
    let(:logged_in_with_france_connect) { false }

    before do
      stub_const("PRO_CONNECT", { end_session_endpoint: 'http://pro-connect/logout' })
      stub_const("FRANCE_CONNECT", { end_session_endpoint: 'http://france-connect/logout' })

      sign_in user

      if logged_in_with_france_connect
        cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME] = 'id_token'
        cookies.encrypted[FranceConnectController::STATE_COOKIE_NAME] = 'state'
      end

      cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = { value: { user_id: user.id }.to_json }

      delete :destroy
    end

    it 'user is sign out' do
      expect(subject.current_user).to be_nil
    end

    it 'loged_in_with_france_connect current_user attribut is nil' do
      user.reload
      expect(user.loged_in_with_france_connect.present?).to be_falsey
    end

    context 'when user is connect with france connect particulier' do
      let(:logged_in_with_france_connect) { true }
      let(:loged_in_with_france_connect) { User.loged_in_with_france_connects.fetch(:particulier) }

      it 'redirect to france connect logout page' do
        h = { id_token_hint: 'id_token', post_logout_redirect_uri: root_url, state: 'state' }
        expect(response).to redirect_to("#{FRANCE_CONNECT[:end_session_endpoint]}?#{h.to_query}")

        [
          FranceConnectController::ID_TOKEN_COOKIE_NAME,
          FranceConnectController::STATE_COOKIE_NAME,
        ].map(&:to_s).each do |cookie_name|
          expect(response.cookies.keys).to include(cookie_name)
          expect(response.cookies[cookie_name]).to be_nil
        end
      end
    end

    context 'when user is not connect with france connect' do
      it 'redirect to root page' do
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is connect with pro connect' do
      let(:loged_in_with_france_connect) { nil }
      let(:pro_connect_id_token) { 'qwerty' }

      it 'redirect to pro connect logout page' do
        expect(response.location).to include(pro_connect_id_token)
        expect(instructeur.reload.pro_connect_id_token).to be_nil
      end

      it "deletes the pro_connect_session_info cookie" do
        expect(response.cookies.keys).to include(ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME.to_s)
        expect(response.cookies[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME]).to be_nil
      end
    end
  end

  describe '#new' do
    subject { get :new }

    it { expect(subject.status).to eq 200 }

    context 'when a procedure location has been stored' do
      let(:procedure) { create :procedure, :published }

      before do
        controller.store_location_for(:user, commencer_path(path: procedure.path))
      end

      it 'makes the saved procedure available' do
        expect(subject.status).to eq 200
        expect(assigns(:procedure)).to eq procedure
      end
    end
  end

  describe '#sign_in_by_link' do
    context 'when the instructeur has non other account' do
      let(:instructeur) { create(:instructeur) }
      let!(:good_jeton) { instructeur.create_trusted_device_token }
      let(:jeton) { good_jeton }
      let(:logged) { false }
      let(:valid_token) { true }

      before do
        if logged
          sign_in(instructeur.user)
        end
        allow(controller).to receive(:trust_device).and_call_original
        allow(controller).to receive(:send_login_token_or_bufferize)
        allow(controller).to receive_message_chain(:message_encryptor_service, :encrypt_and_sign).with(instructeur.user.email, purpose: :reset_link, expires_in: 1.hour).and_return('panpan')

        allow_any_instance_of(TrustedDeviceToken).to receive(:token_valid?).and_return(valid_token)
        post :sign_in_by_link, params: { id: instructeur.id, jeton: jeton }
      end

      context 'when the instructeur is not logged in' do
        context 'when the token is valid' do
          it do
            is_expected.to redirect_to new_user_session_path
            expect(controller.current_instructeur).to be_nil
            expect(controller).to have_received(:trust_device)
            expect(TrustedDeviceToken.find_by(token: jeton).activated_at).to be_present
          end
        end

        context 'when the token is invalid' do
          let(:valid_token) { false }
          it 'redirects to link_sent_path with encrypted email' do
            expect(response).to redirect_to link_sent_path(email: 'panpan')
          end
          it do
            expect(controller.current_instructeur).to be_nil
            expect(controller).not_to have_received(:trust_device)
            expect(controller).to have_received(:send_login_token_or_bufferize)
          end
        end

        context 'when the token does not exist' do
          let(:jeton) { 'I do not exist' }

          it do
            is_expected.to redirect_to root_path
            expect(controller.current_instructeur).to be_nil
            expect(controller).not_to have_received(:trust_device)
            expect(controller).not_to have_received(:send_login_token_or_bufferize)
            expect(flash.alert).to eq('Votre lien est invalide.')
          end
        end
      end

      context 'when the instructeur is logged in' do
        let(:logged) { true }

        context 'when the token is valid' do
          # redirect to root_path, then redirect to instructeur_procedures_path (see root_controller)
          it do
            is_expected.to redirect_to root_path
            expect(controller.current_instructeur).to eq(instructeur)
            expect(controller).to have_received(:trust_device)
            expect(controller.current_instructeur.user.email_verified_at).not_to be_nil
          end
        end

        context 'when the token is invalid' do
          let(:valid_token) { false }

          it do
            is_expected.to redirect_to link_sent_path(email: 'panpan')
            expect(controller.current_instructeur).to eq(instructeur)
            expect(controller).not_to have_received(:trust_device)
            expect(controller).to have_received(:send_login_token_or_bufferize)
          end
        end
      end
    end
  end

  describe '#trust_device and #trusted_device?' do
    subject { controller.trusted_device? }

    context 'when the trusted cookie is not present' do
      it { is_expected.to be false }
    end

    context 'when the cookie is outdated' do
      before do
        emission_date = Time.zone.now - TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD - 1.minute
        controller.trust_device(emission_date)
      end

      it { is_expected.to be false }
    end

    context 'when the cookie is ok' do
      before { controller.trust_device(Time.zone.now) }

      it { is_expected.to be true }
    end
  end

  describe '#link_sent' do
    render_views

    before { get :link_sent, params: { email: signed_email } }

    let(:signed_email) { controller.message_encryptor_service.encrypt_and_sign(link_email, purpose: :reset_link) }

    context 'when the email is legit' do
      let(:link_email) { 'a@a.com' }

      it { expect(response.body).to include(link_email) }
    end

    context 'when the email is evil' do
      [
        'Hello, I am an evil email',
        'a@a%C2%A0evil%C2%A0text%C2%A0with%C2%A0spaces',
      ].each do |evil_attempt|
        let(:link_email) { evil_attempt }

        it { expect(response).to redirect_to(root_path) }
      end
    end
  end

  describe '#reset_link_sent' do
    subject { post :reset_link_sent, params: params }
    let(:params) { {} }

    context 'when the instructeur is not signed in but provides a valid signed email' do
      let(:instructeur) { create(:instructeur) }
      let(:signed_email) do
        controller.message_encryptor_service.encrypt_and_sign(instructeur.email, purpose: :reset_link)
      end
      let(:params) { { signed_email: } }

      before do
        allow(controller).to receive(:signed_email_for_instructeur)
          .with(instructeur)
          .and_return('un-joli-jeton')
      end

      it 'sends the login token and redirects to link_sent' do
        expect(InstructeurMailer).to receive(:send_login_token).with(instructeur, anything, anything).and_return(double(deliver_later: true))
        expect { subject }.to change { instructeur.trusted_device_tokens.count }.by(1)
        expect(response).to redirect_to(link_sent_path(email: 'un-joli-jeton'))
      end
    end
  end

  describe '#logout' do
    subject { get :logout }

    it 'redirects to root_path' do
      expect(subject).to redirect_to(root_path)
    end
  end
end
