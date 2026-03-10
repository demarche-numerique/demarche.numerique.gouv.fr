# frozen_string_literal: true

describe FranceConnectController, type: :controller do
  let(:birthdate) { '20150821' }
  let(:email) { 'EMAIL_from_fc@test.com' }
  let(:user_info) do
    {
      'sub' => 'blablabla',
      'given_name' => 'titi',
      'family_name' => 'toto',
      'birthdate' => birthdate,
      'birthplace' => '1234',
      'birthcountry' => '12345',
      'gender' => 'M',
      'email' => email,
    }
  end

  before { allow(FranceConnectService).to receive(:enabled?).and_return(true) }

  describe '#auth' do
    subject { get :login }

    before { allow(FranceConnectService).to receive(:authorization_uri).and_return(['uri', 'state', 'nonce']) }

    it do
      is_expected.to have_http_status(:redirect)
      expect(cookies.encrypted[FranceConnectController::STATE_COOKIE_NAME]).to be_present
      expect(cookies.encrypted[FranceConnectController::NONCE_COOKIE_NAME]).to be_present
    end
  end

  describe '#callback' do
    let(:code) { 'plop' }
    let(:state) { 'good_state' }

    before do
      cookies.encrypted[FranceConnectController::STATE_COOKIE_NAME] = 'good_state'
    end

    subject { get :callback, params: { code:, state: } }

    context 'when params are missing' do
      subject { get :callback }

      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when param code is missing' do
      let(:code) { nil }

      it do
        is_expected.to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include('Une erreur est survenue lors de la connexion')
      end
    end

    context 'when an error occurs' do
      let(:params) { { code: '', state: '', error: } }

      def check_error_handling(error, expected_message)
        get :callback, params: { error: }
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include(expected_message)
      end

      context 'of type invalid_scope' do
        let(:error) { 'invalid_scope' }

        it do
          check_error_handling('invalid_scope', 'Veuillez essayer un autre mode de connexion')

          check_error_handling('invalid_request', 'Veuillez essayer un autre mode de connexion')

          check_error_handling('access_denied', 'Veuillez réessayer.')

          check_error_handling('server_error', 'Veuillez réessayer.')

          check_error_handling('temporarily_unavailable', 'Veuillez réessayer.')
        end
      end
    end

    context 'when param code is empty' do
      let(:code) { '' }

      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when code is correct' do
      before do
        allow(FranceConnectService).to receive(:retrieve_user_informations)
          .and_return([user_info, 'id_token'])
      end

      context 'when france_connect_particulier_id exists in database' do
        let(:fci_attributes) do
          FranceConnectService::UPDATABLE_FRANCE_CONNECT_CLAIMS
            .transform_values { |fc_claim| user_info[fc_claim] }
            .merge(
              france_connect_particulier_id: user_info['sub'],
              user_id: fc_user&.id
            )
        end
        let!(:fci) { FranceConnectInformation.create!(fci_attributes) }

        context 'and is linked to an user' do
          let(:fc_user) { create(:user, email: 'associated_user@a.com') }

          it { expect { subject }.not_to change { FranceConnectInformation.count } }
          it { expect { subject }.to change { fc_user.reload.last_sign_in_at } }

          it 'signs in with the fci associated user' do
            subject
            expect(controller.current_user).to eq(fc_user)
            expect(fc_user.reload.loged_in_with_france_connect).to eq(User.loged_in_with_france_connects.fetch(:particulier))
            expect(cookies.encrypted[FranceConnectController::NONCE_COOKIE_NAME]).to be_nil
            expect(cookies.encrypted[FranceConnectController::ID_TOKEN_COOKIE_NAME]).to eq('id_token')
            expect(fc_user.preferred_domain_demarche_numerique_gouv_fr?).to be_truthy
          end

          context 'and the user has a stored location' do
            let(:stored_location) { '/plip/plop' }
            before { controller.store_location_for(:user, stored_location) }

            it { is_expected.to redirect_to(stored_location) }
          end

          context 'but the state is not correct' do
            let(:state) { 'bad_state' }

            it 'redirects to the login path' do
              subject
              expect(response).to redirect_to(new_user_session_path)
            end
          end
        end

        context 'and is linked an instructeur' do
          let(:fc_user) { create(:instructeur, email: 'another_email@a.com').user }

          before { subject }

          it do
            expect(response).to redirect_to(new_user_session_path)
            expect(flash[:alert]).to be_present
          end
        end

        context 'and is not linked to an user' do
          let(:fc_user) { nil }

          context 'and no user with the same email exists' do
            it 'render the choose email template to select good email' do
              expect { subject }.to change { User.count }.by(0)
              expect(subject).to render_template(:choose_email)
            end
          end

          context 'and an user with the same email exists' do
            let!(:preexisting_user) { create(:user, email: email) }

            it 'renders the merge page' do
              expect { subject }.not_to change { User.count }

              expect(response).to render_template(:merge)
            end
          end
          context 'and an instructeur with the same email exists' do
            let!(:preexisting_user) { create(:instructeur, email: email) }

            it 'redirects to the login path' do
              expect { subject }.not_to change { User.count }

              expect(response).to redirect_to(new_user_session_path)
              expect(flash[:alert]).to eq(I18n.t('errors.messages.france_connect.forbidden_html', app_name: APPLICATION_NAME))
            end
          end
        end
      end

      context 'when france_connect_particulier_id does not exist in database' do
        it { expect { subject }.to change { FranceConnectInformation.count }.by(1) }

        it { is_expected.to render_template(:choose_email) }
      end
    end

    context 'when code is not correct' do
      before do
        allow(FranceConnectService).to receive(:retrieve_user_informations) { raise Rack::OAuth2::Client::Error.new(500, error: 'Unknown') }
        subject
      end

      it do
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe '#merge_using_fc_email' do
    subject { post :merge_using_fc_email, params: { merge_token: merge_token } }

    let(:fci_attributes) do
      FranceConnectService::UPDATABLE_FRANCE_CONNECT_CLAIMS
        .transform_values { |fc_claim| user_info[fc_claim] }
        .merge(france_connect_particulier_id: user_info['sub'])
    end
    let!(:fci) { FranceConnectInformation.create!(fci_attributes) }
    let(:merge_token) { fci.create_merge_token! }

    before do
      allow(UserMailer).to receive_message_chain(:custom_confirmation_instructions, :deliver_later)
    end

    context 'when the merge token is valid' do
      it do
        expect(User.last.email).not_to eq(email.downcase)

        subject

        user = User.last

        expect(user.email).to eq(email.downcase)
        expect(user.email_verified_at).not_to be_nil
        expect(fci.reload.merge_token).to be_nil
        expect(response).to redirect_to(root_path(user))
      end
    end

    context 'when the merge token is invalid' do
      let(:merge_token) { 'invalid_token' }

      it 'redirects to root_path with an alert' do
        subject
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Le délai pour fusionner les comptes FranceConnect et demarche.numerique.gouv.fr est expiré. Veuillez recommencer la procédure pour vous fusionner les comptes.")
      end
    end

    context 'when @fci is not valid for merge' do
      before do
        merge_token
        fci.update!(merge_token_created_at: 2.years.ago)
      end

      it 'redirects to root_path with an alert' do
        subject

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Le délai pour fusionner les comptes FranceConnect et demarche.numerique.gouv.fr est expiré. Veuillez recommencer la procédure pour vous fusionner les comptes.')
      end
    end
  end

  describe '#confirm_email' do
    let!(:user) { create(:user) }
    let!(:fci_attributes) do
      FranceConnectService::UPDATABLE_FRANCE_CONNECT_CLAIMS
        .transform_values { |fc_claim| user_info[fc_claim] }
        .merge(
          france_connect_particulier_id: user_info['sub'],
          user_id: user&.id
        )
    end
    let!(:fci) { FranceConnectInformation.create!(fci_attributes) }

    before do
      fci.send_custom_confirmation_instructions
      user.reload
    end

    context 'when the confirmation token is valid' do
      before do
        get :confirm_email, params: { token: user.confirmation_token }
        user.reload
      end

      it do
        expect(user.email_verified_at).to be_present
        expect(user.confirmation_token).to be_nil

        expect(response).to redirect_to(root_path(user))
        expect(flash[:notice]).to eq('Votre adresse électronique est bien vérifiée')
      end
    end

    context 'when invites are pending' do
      let!(:invite) { create(:invite, email: user.email, user: nil) }

      it 'links pending invites' do
        get :confirm_email, params: { token: user.confirmation_token }
        invite.reload
        expect(invite.user).to eq(user)
      end
    end

    context 'when the confirmation token is expired' do
      let!(:expired_user_confirmation) do
        create(:user, confirmation_token: 'expired_token', confirmation_sent_at: 3.days.ago)
      end

      it 'redirects to root path with an alert when FranceConnectInformation is not found' do
        get :confirm_email, params: { token: 'expired_token' }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t('france_connect.flash.confirmation_mail_resent_error'))
      end

      context 'when FranceConnectInformation exists' do
        let!(:france_connect_information) do
          create(:france_connect_information, user: expired_user_confirmation)
        end

        before do
          allow(UserMailer).to receive_message_chain(:custom_confirmation_instructions, :deliver_later)
        end

        it 'resends the confirmation email and redirects to root path with a notice' do
          get :confirm_email, params: { token: 'expired_token' }

          expect(UserMailer).to have_received(:custom_confirmation_instructions)
            .with(expired_user_confirmation, expired_user_confirmation.reload.confirmation_token)

          expect(response).to redirect_to(root_path)
          expect(flash[:notice]).to eq(I18n.t('france_connect.flash.confirmation_mail_resent'))
        end
      end
    end

    context 'when a different user is signed in' do
      let!(:expired_user_confirmation) do
        create(:user, confirmation_token: 'expired_token', confirmation_sent_at: 3.days.ago)
      end

      let(:another_user) { create(:user) }

      before { sign_in(another_user) }

      it 'signs out the current user and redirects to sign in path' do
        expect_any_instance_of(FranceConnectInformation).not_to receive(:send_custom_confirmation_instructions)
        expect(controller).to receive(:sign_out).with(:user)

        get :confirm_email, params: { token: 'expired_token' }

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq(I18n.t('france_connect.flash.redirect_new_user_session'))
      end
    end
  end

  describe '#set_user_by_confirmation_token' do
    let(:current_user) { create(:user) }
    let!(:confirmation_user) { create(:user, confirmation_token: 'valid_token') }

    before { sign_in current_user }

    it 'signs out current user and redirects to new session path when users do not match' do
      expect(controller).to receive(:sign_out).with(:user)

      get :confirm_email, params: { token: 'valid_token' }

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(I18n.t('france_connect.flash.redirect_new_user_session'))
    end

    context 'when user is not found' do
      it 'redirects to root path with user not found alert' do
        get :confirm_email, params: { token: 'invalid_token' }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t('france_connect.flash.user_not_found'))
      end
    end
  end

  RSpec.shared_examples "a method that needs a valid merge token" do
    context 'when the merge token is invalid' do
      before do
        allow(Current).to receive(:application_name).and_return('demarche.numerique.gouv.fr')
        merge_token
        fci.update(merge_token_created_at: 2.years.ago)
      end

      it do
        if format == :js
          subject
          expect(response.body).to eq("window.location.href='/'")
        else
          expect(subject).to redirect_to root_path
        end
        expect(flash.alert).to eq('Le délai pour fusionner les comptes FranceConnect et demarche.numerique.gouv.fr est expiré. Veuillez recommencer la procédure pour vous fusionner les comptes.')
      end
    end
  end

  describe '#merge_using_password' do
    let(:fci_attributes) do
      FranceConnectService::UPDATABLE_FRANCE_CONNECT_CLAIMS
        .transform_values { |fc_claim| user_info[fc_claim] }
        .merge(france_connect_particulier_id: user_info['sub'])
    end
    let(:fci) { FranceConnectInformation.create!(fci_attributes) }
    let(:merge_token) { fci.create_merge_token! }
    let(:email) { 'EXISTING_account@a.com ' }
    let(:password) { SECURE_PASSWORD }
    let(:format) { :turbo_stream }

    subject { post :merge_using_password, params: { merge_token: merge_token, password: password }, format: format }

    it_behaves_like "a method that needs a valid merge token"

    context 'when the user is not found' do
      it 'does not log' do
        subject
        fci.reload

        expect(fci.user).to be_nil
        expect(fci.merge_token).not_to be_nil
        expect(controller.current_user).to be_nil
      end
    end

    context 'when the credentials are ok' do
      let!(:user) { create(:user, email: email, password: password) }

      it 'merges the account, signs in, and delete the merge token' do
        subject
        fci.reload

        expect(fci.user).to eq(user)
        expect(fci.merge_token).to be_nil
        expect(controller.current_user).to eq(user)
      end

      context 'but the targeted user is an instructeur' do
        let!(:user) { create(:instructeur, email: email, password: password).user }

        it 'redirects to the root page' do
          subject

          expect { fci.reload }.to raise_error(ActiveRecord::RecordNotFound)

          expect(fci.merge_token).not_to be_nil
          expect(controller.current_user).to be_nil
        end
      end
    end

    context 'when the credentials are not ok' do
      let!(:user) { create(:user, email: email, password: 'another password #$21$%%') }

      it 'increases the failed attempts counter' do
        subject
        fci.reload

        expect(fci.user).to be_nil
        expect(fci.merge_token).not_to be_nil
        expect(controller.current_user).to be_nil
        expect(user.reload.failed_attempts).to eq(1)
      end
    end
  end

  describe '#merge_using_email_link' do
    let(:fci_attributes) do
      FranceConnectService::UPDATABLE_FRANCE_CONNECT_CLAIMS
        .transform_values { |fc_claim| user_info[fc_claim] }
        .merge(france_connect_particulier_id: user_info['sub'])
    end
    let(:fci) { FranceConnectInformation.create!(fci_attributes) }
    let!(:email_merge_token) { fci.create_email_merge_token! }

    context 'when the merge_token is ok and the user is found' do
      subject do
        post :merge_using_email_link, params: { email_merge_token: }
      end

      before do
        allow(Current).to receive(:application_name).and_return('demarche.numerique.gouv.fr')
        fci.update!(requested_email: email.downcase)
      end

      let!(:user) { create(:user, email:, password: SECURE_PASSWORD) }

      it 'merges the account, signs in, and delete the merge token' do
        subject
        fci.reload

        expect(fci.user).to eq(user)
        expect(fci.merge_token).to be_nil
        expect(fci.email_merge_token).to be_nil
        expect(controller.current_user).to eq(user)
        expect(flash[:notice]).to eq("Les comptes FranceConnect et #{Current.application_name} sont à présent fusionnés")
      end

      context 'but the targeted user is an instructeur' do
        let!(:user) { create(:instructeur, email: email, password: SECURE_PASSWORD).user }

        it 'redirects to the new session' do
          subject
          expect(FranceConnectInformation.exists?(fci.id)).to be_falsey
          expect(controller.current_user).to be_nil
          expect(response).to redirect_to(new_user_session_path)
          expect(flash[:alert]).to eq(I18n.t('errors.messages.france_connect.forbidden_html', app_name: APPLICATION_NAME))
        end
      end
    end
  end

  describe '#send_email_merge_request' do
    let(:fci_attributes) do
      FranceConnectService::UPDATABLE_FRANCE_CONNECT_CLAIMS
        .transform_values { |fc_claim| user_info[fc_claim] }
        .merge(france_connect_particulier_id: user_info['sub'])
    end
    let(:fci) { FranceConnectInformation.create!(fci_attributes) }
    let(:merge_token) { fci.create_merge_token! }
    let(:email) { 'requested_email@.a.com' }

    subject { post :send_email_merge_request, params: { merge_token: merge_token, email: } }

    it 'renew token' do
      allow(UserMailer).to receive_message_chain(:france_connect_merge_confirmation, :deliver_later)
      subject

      fci.reload
      expect(fci.requested_email).to eq(email)
      expect(fci.email_merge_token).to be_present

      expect(UserMailer).to have_received(:france_connect_merge_confirmation).with(email, fci.email_merge_token, fci.email_merge_token_created_at)

      expect(response).to redirect_to(root_path)
    end
  end
end
