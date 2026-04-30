# frozen_string_literal: true

describe ProConnectController, type: :controller do
  describe '#required' do
    subject { get :required }
    render_views

    it 'renders the required template' do
      subject
      expect(response.body).to have_text("Connexion ProConnect")
    end
  end

  describe '#login' do
    let(:uri) { 'https://www.proconnect.gouv.fr' }
    let(:state) { 'state' }
    let(:nonce) { 'nonce' }

    before do
      expect(ProConnectService).to receive(:authorization_uri).and_return([uri, state, nonce])
      get :login
    end

    it do
      expect(state_cookie).to eq(state)
      expect(nonce_cookie).to eq(nonce)
      expect(response).to redirect_to(uri)
    end
  end

  describe '#callback' do
    let(:email) { 'i@email.com' }
    let(:original_state) { 'original_state' }
    let(:nonce) { 'nonce' }
    let(:id_token) { 'id_token' }
    let(:user_info) do
      {
        'sub' => 'sub',
        'email' => email,
        'given_name' => 'given',
        'usual_name' => 'usual',
        'idp_id' => idp_id,
      }
    end
    let(:amr) { [] }
    let(:idp_id) { 'an_id' }
    subject { get :callback, params: { code: code, state: state } }

    before do
      cookies.encrypted[controller.class::STATE_COOKIE_NAME] = original_state
      cookies.encrypted[controller.class::NONCE_COOKIE_NAME] = nonce
    end

    context 'when the callback code is correct' do
      let(:code) { 'correct' }
      let(:state) { original_state }

      context 'and user_info returns some info' do
        before do
          expect(ProConnectService).to receive(:user_info).with(code, nonce).and_return([user_info, id_token, amr])
        end

        context 'and the user does not have an account yet' do
          let(:initial_instructeur_count) { Instructeur.count }

          before do
            expect(controller).to receive(:sign_in)
          end

          it 'creates the user but not an instructeur' do
            expect { subject }.to change { User.count }.by(1).and change { Instructeur.count }.by(0)

            last_user = User.last

            expect(last_user.email).to eq(email)
            expect(last_user.confirmed_at).to be_present
            expect(last_user.email_verified_at).to be_present
            expect(response).to redirect_to(root_path)
            expect(state_cookie).to be_nil
            expect(nonce_cookie).to be_nil
            expect(Instructeur.count).to eq(initial_instructeur_count)
          end

          context 'when invites are pending' do
            let!(:invite) { create(:invite, email:, user: nil) }

            it 'links invites to the new user' do
              expect { subject }.to change { invite.reload.user }.from(nil)
              expect(invite.reload.user.email).to eq(email)
            end
          end
        end

        context 'and the user already has an account but is not an instructeur' do
          let!(:user) { create(:user, email: email) }
          let(:initial_instructeur_count) { Instructeur.count }

          context 'and the instructeur is not using mon compte pro' do
            before do
              expect(controller).to receive(:sign_in)
            end

            it 'does not create an instructeur' do
              expect { subject }.to change { User.count }.by(0).and change { Instructeur.count }.by(0)
              expect(response).to redirect_to(root_path)
              expect(Instructeur.count).to eq(initial_instructeur_count)
            end
          end
        end

        context 'and the user already has an account as an instructeur' do
          let!(:instructeur) { create(:instructeur, email: email) }
          let(:initial_instructeur_count) { Instructeur.count }

          context 'and the instructeur is not using mon compte pro' do
            before do
              expect(controller).to receive(:sign_in)
            end

            it 'updates the instructeur pro_connect information' do
              expect { subject }.to change { User.count }.by(0).and change { Instructeur.count }.by(0)
              instructeur.reload

              expect(instructeur.pro_connect_id_token).to eq('id_token')
              expect(instructeur.user.pro_connect_informations.first.sub).to eq('sub')
              expect(instructeur.user.pro_connect_informations.first.given_name).to eq('given')
              expect(instructeur.user.pro_connect_informations.first.usual_name).to eq('usual')
              expect(response).to redirect_to(root_path)
              expect(Instructeur.count).to eq(initial_instructeur_count)
            end

            it "sets user values and cookies" do
              expect { subject }.to change { instructeur.user.reload.email_verified_at }.from(nil)
              expect(instructeur.user.preferred_domain_demarche_numerique_gouv_fr?).to be_truthy

              expect(cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME]).to eq({ user_id: instructeur.user.id, mfa: false }.to_json)
            end
          end

          context 'and the instructeur uses Mon Compte Pro without MFA' do
            let(:amr) { ['pwd'] }
            let(:idp_id) { ProConnectController::MON_COMPTE_PRO_IDP_ID }
            let(:uri) { 'https://mfa.proconnect.gouv.fr' }

            it 'redirects to Pro Connect login with MFA enforced' do
              expect(ProConnectService).to receive(:authorization_uri)
                .with(force_mfa: true, login_hint: email)
                .and_return([uri, original_state, nonce])

              subject

              expect(response).to redirect_to('https://mfa.proconnect.gouv.fr')
              expect(state_cookie).to eq(original_state)
              expect(nonce_cookie).to eq(nonce)
            end
          end

          context 'and the user uses Mon Compte Pro with MFA' do
            let(:amr) { ['pwd', 'totp', 'mfa'] }
            let(:idp_id) { ProConnectController::MON_COMPTE_PRO_IDP_ID }

            it 'logs in the user' do
              expect(controller).to receive(:sign_in)

              subject

              expect(cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME]).to eq({ user_id: instructeur.user.id, mfa: true }.to_json)
            end
          end
        end
      end

      context 'when connecting multiple times' do
        context 'with the same domain' do
          let!(:user) { create(:user, email: email) }
          let(:code) { 'correct' }
          let(:state) { original_state }
          let(:initial_instructeur_count) { Instructeur.count }

          before do
            expect(ProConnectService).to receive(:user_info).with(code, nonce).and_return([user_info, id_token, amr]).twice
            expect(controller).to receive(:sign_in).twice
          end

          it 'does not create an instructeur' do
            get :callback, params: { code: code, state: state }
            get :callback, params: { code: code, state: state }

            expect(Instructeur.count).to eq(initial_instructeur_count)
          end
        end

        context 'with different domains' do
          let!(:user) { create(:user, email: email) }
          let(:code) { 'correct' }
          let(:state) { original_state }
          let(:initial_instructeur_count) { Instructeur.count }

          before do
            expect(controller).to receive(:sign_in).twice
          end

          it 'does not create an instructeur' do
            expect(ProConnectService).to receive(:user_info).with(code, nonce).and_return([user_info, id_token, amr])
            get :callback, params: { code: code, state: state }

            expect(ProConnectService).to receive(:user_info).with(code, nonce).and_return([user_info.merge('sub' => 'sub2'), id_token, amr])
            get :callback, params: { code: code, state: state }

            expect(Instructeur.count).to eq(initial_instructeur_count)
          end
        end
      end

      context 'but user_info raises an error' do
        let(:initial_instructeur_count) { Instructeur.count }

        before do
          expect(ProConnectService).to receive(:user_info).and_raise(Rack::OAuth2::Client::Error.new(500, error: 'Unknown'))
        end

        it 'aborts the process' do
          expect { subject }.to change { User.count }.by(0).and change { Instructeur.count }.by(0)
          expect(response).to redirect_to(new_user_session_path)
          expect(Instructeur.count).to eq(initial_instructeur_count)
        end
      end
    end

    context 'when the callback state is not the original' do
      let(:code) { 'correct' }
      let(:state) { 'another state' }
      let(:initial_instructeur_count) { Instructeur.count }

      before { subject }

      it 'aborts the process' do
        expect { subject }.to change { User.count }.by(0).and change { Instructeur.count }.by(0)
        expect(response).to redirect_to(new_user_session_path)
        expect(Instructeur.count).to eq(initial_instructeur_count)
      end
    end

    context 'when no state cookie is set and no state param is provided' do
      let(:code) { 'correct' }

      before { cookies.delete(controller.class::STATE_COOKIE_NAME) }

      subject { get :callback, params: { code: } }

      it 'rejects the callback (no nil == nil bypass)' do
        expect(ProConnectService).not_to receive(:user_info)
        expect { subject }.to change { User.count }.by(0)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when the callback code is blank' do
      let(:code) { '' }
      let(:state) { original_state }
      let(:initial_instructeur_count) { Instructeur.count }

      it 'aborts the process' do
        expect { subject }.to change { User.count }.by(0).and change { Instructeur.count }.by(0)
        expect(response).to redirect_to(new_user_session_path)
        expect(Instructeur.count).to eq(initial_instructeur_count)
      end
    end
  end

  def state_cookie
    cookies.encrypted[controller.class::STATE_COOKIE_NAME]
  end

  def nonce_cookie
    cookies.encrypted[controller.class::NONCE_COOKIE_NAME]
  end
end
