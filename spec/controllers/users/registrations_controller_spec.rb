# frozen_string_literal: true

describe Users::RegistrationsController, type: :controller do
  let(:email) { 'test@octo.com' }
  let(:password) { SECURE_PASSWORD }

  let(:user) { { email: email, password: password } }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe '#new' do
    subject { get :new }

    it do
      expect(subject).to have_http_status(:ok)
      expect(subject).to render_template(:new)
    end

    context 'when an email address is provided' do
      render_views true
      subject { get :new, params: { user: { email: 'test@exemple.fr' } } }

      it 'prefills the form with the email address' do
        expect(subject.body).to include('test@exemple.fr')
      end
    end

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

  describe '#create' do
    subject do
      post :create, params: { user: user }
    end

    before do
      allow(Current).to receive(:host).and_return(ENV.fetch("APP_HOST"))
    end

    context 'when user is correct' do
      it 'sends confirmation instruction' do
        message = double()
        expect(DeviseUserMailer).to receive(:confirmation_instructions).and_return(message)
        expect(message).to receive(:deliver_later)

        subject

        expect(User.last.preferred_domain_demarche_numerique_gouv_fr?).to be_truthy
      end
    end

    context 'when user is not correct' do
      let(:user) { { email: '', password: password } }

      it 'not sends confirmation instruction' do
        expect(DeviseUserMailer).not_to receive(:confirmation_instructions)

        subject
      end
    end

    context 'when the user already exists' do
      let!(:existing_user) { create(:user, email: email, password: password, confirmed_at: confirmed_at) }

      before do
        allow(UserMailer).to receive(:new_account_warning).and_return(double(deliver_later: 'deliver'))
      end

      context 'and the user is confirmed' do
        let(:confirmed_at) { Time.zone.now }

        before { subject }

        it 'sends an email to the user, stating that the account already exists' do
          expect(UserMailer).to have_received(:new_account_warning)
        end

        it 'redirects to confirmation page with signed email in url' do
          email_param = CGI.parse(URI.parse(response.location).query)['email'].first
          decrypted_email = controller.message_encryptor_service.decrypt_and_verify(email_param, purpose: :email_confirmation)
          expect(decrypted_email).to eq(user[:email])
        end
      end

      context 'and the user is not confirmed' do
        let(:confirmed_at) { nil }

        before do
          expect_any_instance_of(User).to receive(:resend_confirmation_instructions)
          subject
        end

        it 'does not send a warning email' do
          expect(UserMailer).not_to have_received(:new_account_warning)
        end

        it 'redirects to confirmation page with signed email (not plain text)' do
          expect(response).to redirect_to(/\/users\/confirmation\/new\?email=/)

          email_param = CGI.parse(URI.parse(response.location).query)['email'].first
          decrypted_email = controller.message_encryptor_service.decrypt_and_verify(email_param, purpose: :email_confirmation)
          expect(decrypted_email).to eq(user[:email])
        end
      end
    end

    context 'when the email param is sent as a non-scalar value' do
      let!(:other_user) { create(:user, email: 'someone-else@example.com', confirmed_at: Time.zone.now) }

      before do
        allow(UserMailer).to receive(:new_account_warning).and_return(double(deliver_later: 'deliver'))
      end

      subject(:non_scalar_email_request) do
        post :create, params: { user: { email: ['anything'], password: password } }
      end

      it 'does not look up an unrelated existing user' do
        expect(UserMailer).not_to receive(:new_account_warning).with(other_user, anything)

        non_scalar_email_request
      end

      it 'does not redirect to a confirmation page that discloses an unrelated user email' do
        non_scalar_email_request

        if response.redirect? && response.location.match?(/\/users\/confirmation\/new\?email=/)
          email_param = CGI.parse(URI.parse(response.location).query)['email'].first
          decrypted_email = controller.message_encryptor_service.decrypt_and_verify(email_param, purpose: :email_confirmation)
          expect(decrypted_email).not_to eq(other_user.email)
        end
      end
    end
  end
end
