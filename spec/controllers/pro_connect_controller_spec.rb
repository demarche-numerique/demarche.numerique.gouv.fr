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

    before { expect(ProConnectService).to receive(:authorization_uri).and_return([uri, state, nonce]) }

    it do
      get :login

      expect(state_cookie).to eq(state)
      expect(nonce_cookie).to eq(nonce)
      expect(response).to redirect_to(uri)
    end

    context 'when a forced MFA round trip was left behind' do
      before { cookies.encrypted[ProConnectController::MFA_FORCED_FOR_COOKIE_NAME] = 'someone@example.com' }

      it 'clears its marker so the next callback is not read as a failure' do
        get :login

        expect(cookies.encrypted[ProConnectController::MFA_FORCED_FOR_COOKIE_NAME]).to be_nil
      end
    end

    context 'during a migration to ProConnect' do
      let(:account) { administrateurs.default.user }
      let(:migration) { ProConnectMigration.create!(user: account, source_email: account.email) }

      before { session[ProConnectMigrationConcern::SESSION_KEY] = migration.id }

      it 'keeps it from the migration page' do
        get :login, params: { migration: true }

        expect(session[ProConnectMigrationConcern::SESSION_KEY]).to eq(migration.id)
      end

      it 'forgets it when ProConnect is not started from the migration page' do
        get :login

        expect(session[ProConnectMigrationConcern::SESSION_KEY]).to be_nil
      end
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
    let(:acr) { nil }
    let(:idp_id) { 'an_id' }
    let(:auth) { ProConnectService::Authentication.new(user_info:, id_token:, amr:, acr:) }
    subject { get :callback, params: { code: code, state: state } }

    before do
      cookies.encrypted[controller.class::STATE_COOKIE_NAME] = original_state
      cookies.encrypted[controller.class::NONCE_COOKIE_NAME] = nonce
    end

    context 'when the callback code is correct' do
      let(:code) { 'correct' }
      let(:state) { original_state }

      context 'and authenticate returns some info' do
        before do
          expect(ProConnectService).to receive(:authenticate).with(code, nonce).and_return(auth)
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

              cookie = JSON.parse(cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME])
              expect(cookie).to include('user_id' => instructeur.user.id, 'mfa' => false)
              expect(cookie['mfa_at']).to be_present
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
            let(:acr) { 'eidas1-mfa' }
            let(:idp_id) { ProConnectController::MON_COMPTE_PRO_IDP_ID }

            it 'logs in the user' do
              expect(controller).to receive(:sign_in)

              subject

              cookie = JSON.parse(cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME])
              expect(cookie).to include('user_id' => instructeur.user.id, 'mfa' => true)
              expect(cookie['mfa_at']).to be_present
            end

            it 'stores the acr claim' do
              expect(controller).to receive(:sign_in)

              subject

              expect(instructeur.user.pro_connect_informations.first.acr).to eq('eidas1-mfa')
            end
          end

          context 'and ProConnect asserts the MFA with the acr claim only' do
            let(:amr) { ['pwd'] }
            let(:acr) { 'eidas1-mfa' }

            it 'records it as a proof in the ProConnect session' do
              expect(controller).to receive(:sign_in)

              subject

              cookie = JSON.parse(cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME])
              expect(cookie).to include('mfa' => true)
            end
          end
        end

        context 'and the user is an administrateur' do
          let(:administrateur) { administrateurs.default }
          let(:email) { administrateur.user.email }
          let(:amr) { ['pwd', 'mfa'] }

          before do
            allow(ProConnectService).to receive(:enabled?).and_return(true)
            freeze_time
          end

          context 'of the ProConnect wave' do
            before { Flipper.enable(:pro_connect_required_for_all_administrateurs) }

            it 'requires ProConnect from now on' do
              subject

              expect(controller.current_user).to eq(administrateur.user)
              expect(administrateur.reload.pro_connect_required_at).to eq(Time.zone.now)
            end

            context 'but blocked' do
              before { administrateur.user.update!(blocked_at: Time.zone.now) }

              it 'is refused without being tied to ProConnect' do
                subject

                expect(controller.current_user).to be_nil
                expect(administrateur.reload.pro_connect_required_at).to be_nil
              end
            end
          end

          context 'outside the wave' do
            it 'keeps its password' do
              subject

              expect(controller.current_user).to eq(administrateur.user)
              expect(administrateur.reload.pro_connect_required_at).to be_nil
            end
          end
        end

        context 'and the user is an administrateur subject to ProConnect' do
          let(:administrateur) { administrateurs.default }
          let(:email) { administrateur.user.email }

          before do
            allow(ProConnectService).to receive(:enabled?).and_return(true)
            administrateur.update!(pro_connect_required_at: Time.zone.now)
          end

          context 'without MFA' do
            let(:uri) { 'https://mfa.proconnect.gouv.fr' }

            it 'sends it back to ProConnect with the MFA enforced' do
              expect(ProConnectService).to receive(:authorization_uri)
                .with(force_mfa: true, login_hint: email)
                .and_return([uri, original_state, nonce])

              subject

              expect(response).to redirect_to(uri)
              expect(controller.current_user).to be_nil
              expect(cookies.encrypted[ProConnectController::MFA_FORCED_FOR_COOKIE_NAME]).to eq(email)
              expect(cookies[ProConnectSessionConcern::ADMINISTRATEUR_DEVICE_COOKIE_NAME]).to be_present
            end
          end

          context 'without MFA, after the MFA was enforced for another account' do
            let(:uri) { 'https://mfa.proconnect.gouv.fr' }

            before { cookies.encrypted[ProConnectController::MFA_FORCED_FOR_COOKIE_NAME] = 'someone.else@example.com' }

            it 'enforces the MFA for this one too' do
              expect(ProConnectService).to receive(:authorization_uri)
                .with(force_mfa: true, login_hint: email)
                .and_return([uri, original_state, nonce])

              subject

              expect(response).to redirect_to(uri)
            end
          end

          context 'without MFA, after the MFA was already enforced once' do
            before { cookies.encrypted[ProConnectController::MFA_FORCED_FOR_COOKIE_NAME] = email }

            it 'gives up with a message instead of looping' do
              expect(ProConnectService).not_to receive(:authorization_uri)

              subject

              expect(controller.current_user).to be_nil
              expect(response).to redirect_to(pro_connect_path)
              expect(flash.alert).to eq(I18n.t('errors.messages.pro_connect.mfa_failed'))
            end
          end

          context 'with MFA, after it was enforced' do
            let(:acr) { 'eidas1-mfa' }

            before { cookies.encrypted[ProConnectController::MFA_FORCED_FOR_COOKIE_NAME] = email }

            it 'signs it in instead of reporting a failed MFA' do
              subject

              expect(controller.current_user).to eq(administrateur.user)
              expect(cookies.encrypted[ProConnectController::MFA_FORCED_FOR_COOKIE_NAME]).to be_nil
            end
          end

          context 'but exempted' do
            before { Flipper.enable_actor(:administrateur_pro_connect_exempted, administrateur.user) }

            it 'signs it in without any MFA' do
              expect(ProConnectService).not_to receive(:authorization_uri)

              subject

              expect(controller.current_user).to eq(administrateur.user)
              expect(cookies[ProConnectSessionConcern::ADMINISTRATEUR_DEVICE_COOKIE_NAME]).to be_nil
            end
          end
        end

        context 'and a migration to ProConnect is pending' do
          let(:administrateur) { administrateurs.default }
          let(:migration) { ProConnectMigration.create!(user: administrateur.user, source_email: administrateur.email) }
          let(:amr) { ['pwd', 'mfa'] }

          before do
            allow(ProConnectService).to receive(:enabled?).and_return(true)
            Flipper.enable(:pro_connect_required_for_all_administrateurs)
            session[ProConnectMigrationConcern::SESSION_KEY] = migration.id
          end

          context 'without MFA' do
            let(:amr) { ['pwd'] }
            let(:email) { 'camille.dupont@ailleurs.fr' }

            it 'enforces the MFA before looking at the address' do
              expect(ProConnectService).to receive(:authorization_uri)
                .with(force_mfa: true, login_hint: email)
                .and_return(['https://mfa.proconnect.gouv.fr', original_state, nonce])

              subject

              expect(migration.reload).to be_started
              expect(User.exists?(email:)).to be false
            end

            context 'after the MFA was already enforced once' do
              before { cookies.encrypted[ProConnectController::MFA_FORCED_FOR_COOKIE_NAME] = email }

              it 'gives up back on the migration page' do
                subject

                expect(response).to redirect_to(pro_connect_migration_path)
                expect(flash.alert).to eq(I18n.t('errors.messages.pro_connect.mfa_failed'))
              end
            end
          end

          context 'with the address of the account' do
            let(:email) { administrateur.email }

            it 'signs the account in, for good' do
              subject

              expect(controller.current_user).to eq(administrateur.user)
              expect(administrateur.reload.pro_connect_required_at).not_to be_nil
            end
          end

          context 'from another domain' do
            let(:email) { 'camille.dupont@ailleurs.fr' }

            it 'sends to the support page without creating an account' do
              subject

              expect(response).to redirect_to(pro_connect_migration_support_path)
              expect(User.exists?(email:)).to be false
              expect(controller.current_user).to be_nil
            end
          end

          context 'started too long ago' do
            let(:email) { 'camille.dupont@ailleurs.fr' }

            before { migration.update!(created_at: 31.minutes.ago) }

            it 'is ignored' do
              subject

              expect(migration.reload).to be_started
              expect(User.exists?(email:)).to be true
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
            expect(ProConnectService).to receive(:authenticate).with(code, nonce).and_return(auth).twice
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
            expect(ProConnectService).to receive(:authenticate).with(code, nonce).and_return(auth)
            get :callback, params: { code: code, state: state }

            expect(ProConnectService).to receive(:authenticate).with(code, nonce).and_return(auth.with(user_info: user_info.merge('sub' => 'sub2')))
            get :callback, params: { code: code, state: state }

            expect(Instructeur.count).to eq(initial_instructeur_count)
          end
        end
      end

      context 'but user_info raises an error' do
        let(:initial_instructeur_count) { Instructeur.count }

        before do
          expect(ProConnectService).to receive(:authenticate).and_raise(Rack::OAuth2::Client::Error.new(500, error: 'Unknown'))
        end

        it 'aborts the process with the ProConnect error message' do
          expect { subject }.to change { User.count }.by(0).and change { Instructeur.count }.by(0)
          expect(response).to redirect_to(new_user_session_path)
          expect(flash.alert).to eq(I18n.t('errors.messages.pro_connect.connexion'))
          expect(Instructeur.count).to eq(initial_instructeur_count)
        end
      end
    end

    context 'when the callback state is not the original' do
      let(:code) { 'correct' }
      let(:state) { 'another state' }
      let(:initial_instructeur_count) { Instructeur.count }

      before { subject }

      it 'aborts the process with the ProConnect error message' do
        expect { subject }.to change { User.count }.by(0).and change { Instructeur.count }.by(0)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash.alert).to eq(I18n.t('errors.messages.pro_connect.connexion'))
        expect(Instructeur.count).to eq(initial_instructeur_count)
      end
    end

    context 'when no state cookie is set and no state param is provided' do
      let(:code) { 'correct' }

      before { cookies.delete(controller.class::STATE_COOKIE_NAME) }

      subject { get :callback, params: { code: } }

      it 'rejects the callback (no nil == nil bypass)' do
        expect(ProConnectService).not_to receive(:authenticate)
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
