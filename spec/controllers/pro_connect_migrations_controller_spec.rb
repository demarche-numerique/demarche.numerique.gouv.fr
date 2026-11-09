# frozen_string_literal: true

describe ProConnectMigrationsController, type: :controller do
  let(:account) { administrateurs.default.user }

  describe '#show' do
    render_views

    before { session[ProConnectMigrationConcern::SESSION_KEY] = ProConnectMigration.create!(user: account, source_email:).id }

    context 'from what looks like a functional mailbox' do
      let(:source_email) { 'contact@exemple.fr' }

      it 'asks for a nominative address' do
        get :show

        expect(response.body).to include('et non l’adresse contact@exemple.fr')
      end
    end

    context 'from a nominative address, suggested to ProConnect' do
      let(:source_email) { 'camille.dupont@exemple.fr' }

      it 'does not ask for another address' do
        get :show

        expect(response.body).not_to include('et non l’adresse')
      end
    end
  end

  describe '#support' do
    render_views

    let(:migration) { ProConnectMigration.create!(user: account, source_email: account.email, state: :domain_mismatch, pro_connect_email: 'camille.dupont@ailleurs.fr') }

    it 'explains why with both addresses' do
      session[ProConnectMigrationConcern::SESSION_KEY] = migration.id

      get :support

      expect(response.body).to include('camille.dupont@ailleurs.fr', account.email)
    end

    it 'sends back to the sign in page without a migration' do
      get :support

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'sends back to the sign in page once the ProConnect return is old' do
      session[ProConnectMigrationConcern::SESSION_KEY] = migration.id
      migration.update!(updated_at: 31.minutes.ago)

      get :support

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'with a code sent to the old address' do
    let(:migration) { ProConnectMigration.create!(user: account, source_email: account.email) }
    let(:auth) { ProConnectService::Authentication.new(user_info: { 'sub' => 'sub', 'email' => 'camille.dupont@exemple.fr' }, id_token: 'id_token', amr: ['pwd', 'mfa'], acr: 'eidas1') }

    before do
      allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(123_456)
      migration.identify!(auth:)
      migration.send_code!(Browser.new(''))
      session[ProConnectMigrationConcern::SESSION_KEY] = migration.id
      cookies.encrypted[ProConnectMigrationConcern::ID_TOKEN_COOKIE_NAME] = auth.id_token
      cookies.encrypted[ProConnectMigrationConcern::IDENTITY_COOKIE_NAME] = { value: auth.to_h.except(:id_token) }
    end

    describe '#verify_code' do
      render_views

      it 'asks whether the account was shared before renaming it' do
        post :verify_code, params: { code: '123456' }

        expect(response).to redirect_to(pro_connect_migration_sharing_path)
        expect(controller.current_user).to be_nil
        expect(account.reload.email).to eq(migration.source_email)
        expect(session[ProConnectMigrationConcern::CODE_VERIFIED_SESSION_KEY]).to eq(migration.id)
      end

      it 'asks again after a wrong code' do
        post :verify_code, params: { code: '000000' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(controller.current_user).to be_nil
      end

      it 'keeps the migration once the code has expired, for a new code' do
        migration.update!(code_sent_at: 11.minutes.ago)

        post :verify_code, params: { code: '123456' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Ce code de sécurité a expiré')
        expect(session[ProConnectMigrationConcern::SESSION_KEY]).to eq(migration.id)
      end

      it 'starts over once the attempts are spent' do
        migration.update!(code_attempts: 4)

        post :verify_code, params: { code: '000000' }

        expect(response).to redirect_to(new_user_session_path)
        expect(session[ProConnectMigrationConcern::SESSION_KEY]).to be_nil
        expect(cookies[ProConnectMigrationConcern::ID_TOKEN_COOKIE_NAME]).to be_nil
        expect(cookies[ProConnectMigrationConcern::IDENTITY_COOKIE_NAME]).to be_nil
      end
    end

    describe '#resend_code' do
      it 'mails a new code, without giving the attempts back nor more time' do
        migration.update_columns(code_sent_at: 2.minutes.ago, code_attempts: 2, updated_at: 20.minutes.ago)

        expect { post :resend_code }.to have_enqueued_mail(UserMailer, :pro_connect_migration_code)

        expect(response).to redirect_to(pro_connect_migration_code_path)
        expect(migration.reload.code_attempts).to eq(2)
        expect(migration.updated_at).to be < 19.minutes.ago
      end

      it 'waits a minute between two codes' do
        expect { post :resend_code }.not_to have_enqueued_mail

        expect(response).to redirect_to(pro_connect_migration_code_path)
      end

      it 'says why it starts over 30 minutes after the ProConnect return' do
        migration.update_columns(code_sent_at: 2.minutes.ago, updated_at: 31.minutes.ago)

        expect { post :resend_code }.not_to have_enqueued_mail

        expect(response).to redirect_to(new_user_session_path)
        expect(flash.alert).to eq(I18n.t('pro_connect_migrations.code.timed_out'))
        expect(session[ProConnectMigrationConcern::SESSION_KEY]).to be_nil
      end

      it 'says nothing to whom has no migration any more' do
        session.delete(ProConnectMigrationConcern::SESSION_KEY)

        post :resend_code

        expect(response).to redirect_to(new_user_session_path)
        expect(flash.alert).to be_nil
      end
    end

    context 'once the code is verified' do
      before { session[ProConnectMigrationConcern::CODE_VERIFIED_SESSION_KEY] = migration.id }

      it 'goes back to the question instead of the code page' do
        get :code

        expect(response).to redirect_to(pro_connect_migration_sharing_path)
      end

      describe '#sharing' do
        render_views

        it 'asks about the old address' do
          get :sharing

          expect(response.body).to include("&quot;#{account.email}&quot; étaient partagés")
        end
      end

      describe '#update_sharing' do
        it 'renames the account, records the answer and signs it in with its ProConnect session' do
          post :update_sharing, params: { shared: 'true' }

          expect(controller.current_user).to eq(account)
          expect(account.reload.email).to eq('camille.dupont@exemple.fr')
          expect(account.pro_connect_informations.pluck(:sub, :amr, :acr)).to eq([['sub', ['pwd', 'mfa'], 'eidas1']])
          expect(migration.reload).to have_attributes(state: 'renamed', shared: true)
          expect(account.instructeur.pro_connect_id_token).to eq('id_token')
          expect(JSON.parse(cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME])).to include('mfa' => true)
          expect(cookies[ProConnectSessionConcern::ADMINISTRATEUR_DEVICE_COOKIE_NAME]).to be_present
          expect(session[ProConnectMigrationConcern::SESSION_KEY]).to be_nil
          expect(response).to redirect_to(pro_connect_migration_completed_path)
        end

        it 'starts over 30 minutes after the ProConnect return' do
          migration.update_columns(updated_at: 31.minutes.ago)

          post :update_sharing, params: { shared: 'true' }

          expect(response).to redirect_to(new_user_session_path)
          expect(flash.alert).to eq(I18n.t('pro_connect_migrations.code.timed_out'))
          expect(account.reload.email).to eq(migration.source_email)
        end
      end
    end

    describe '#update_sharing' do
      it 'asks for the code first, even with the code of a previous migration verified' do
        session[ProConnectMigrationConcern::CODE_VERIFIED_SESSION_KEY] = ProConnectMigration.create!(user: account, source_email: account.email).id

        post :update_sharing, params: { shared: 'true' }

        expect(response).to redirect_to(pro_connect_migration_code_path)
        expect(account.reload.email).to eq(migration.source_email)
      end
    end
  end

  context 'for a co-holder of a migrated address' do
    let(:origin) { ProConnectMigration.create!(user: account, source_email: 'contact@exemple.fr', state: :renamed, shared: true, procedure_ids: [procedures.individual.id]) }
    let(:migration) { ProConnectMigration.create!(user: account, source_email: 'contact@exemple.fr', parent: origin) }

    before do
      allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(123_456)
      migration.update!(state: :awaiting_code, pro_connect_email: 'dominique.martin@exemple.fr')
      migration.send_code!(Browser.new(''))
      session[ProConnectMigrationConcern::SESSION_KEY] = migration.id
      cookies.encrypted[ProConnectMigrationConcern::ID_TOKEN_COOKIE_NAME] = 'id_token'
      cookies.encrypted[ProConnectMigrationConcern::IDENTITY_COOKIE_NAME] = { value: { user_info: { 'sub' => 'sub2', 'email' => 'dominique.martin@exemple.fr' }, amr: ['mfa'], acr: nil } }
    end

    it 'signs the co-holder in with their own account at once, without the question' do
      post :verify_code, params: { code: '123456' }

      co_holder = User.find_by!(email: 'dominique.martin@exemple.fr')
      expect(controller.current_user).to eq(co_holder)
      expect(co_holder.instructeur.pro_connect_id_token).to eq('id_token')
      expect(cookies[ProConnectSessionConcern::ADMINISTRATEUR_DEVICE_COOKIE_NAME]).to be_present
      expect(session[ProConnectMigrationConcern::SESSION_KEY]).to be_nil
      expect(response).to redirect_to(pro_connect_migration_completed_path)
    end
  end

  describe '#completed' do
    render_views

    before do
      sign_in(account)
      account.administrateur.update!(pro_connect_required_at: Time.zone.now)
    end

    it 'confirms the migration with the address of the account' do
      get :completed

      expect(response.body).to include('Migration terminée', "<strong>#{account.email}</strong>")
      expect(response.body).not_to include('et non plus avec l’adresse')
    end

    context 'after a rename' do
      let(:shared) { true }

      before { ProConnectMigration.create!(user: account, source_email: 'contact@exemple.fr', state: :renamed, target_user: account, shared:) }

      it 'warns the holder of a shared address that the others must migrate too' do
        get :completed

        expect(response.body).to include('et non plus avec l’adresse contact@exemple.fr', 'Les autres personnes qui avaient accès')
        expect(response.body).not_to include('Les dossiers déposés en tant qu’usager')
      end

      it 'tells the holder of a shared address where its applications are' do
        dossiers.en_construction.update!(user: account)

        get :completed

        expect(response.body).to include('Les dossiers déposés en tant qu’usager')
      end

      context 'of an address that was not shared' do
        let(:shared) { false }

        it 'says the old address is closed' do
          get :completed

          expect(response.body).to include('contact@exemple.fr sera <strong>désactivé</strong>')
          expect(response.body).not_to include('Les autres personnes qui avaient accès')
        end
      end
    end

    it 'tells a co-holder that the others must migrate too, without the warning of the holder' do
      origin = ProConnectMigration.create!(user: users.usager, source_email: 'contact@exemple.fr', state: :renamed, shared: true)
      ProConnectMigration.create!(user: users.usager, source_email: 'contact@exemple.fr', parent: origin, state: :granted, target_user: account)

      get :completed

      expect(response.body).to include('et non plus avec l’adresse contact@exemple.fr', '<strong>Les autres personnes qui avaient accès')
      expect(response.body).not_to include('Vous êtes maintenant la seule personne')
    end

    it 'sends an administrateur not tied to ProConnect to their procedures' do
      account.administrateur.update!(pro_connect_required_at: nil)

      get :completed

      expect(response).to redirect_to(admin_procedures_path)
    end
  end
end
