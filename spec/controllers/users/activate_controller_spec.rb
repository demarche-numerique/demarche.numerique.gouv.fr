# frozen_string_literal: true

describe Users::ActivateController, type: :controller do
  describe '#resend_verification_email' do
    let(:user) { create(:user, email_verified_at: nil) }

    before { sign_in user }

    context 'when the user has not verified their email' do
      it 'generates a new token and sends the mail' do
        expect {
          post :resend_verification_email
        }.to change { user.reload.confirmation_token }
        expect(flash[:notice]).to eq(I18n.t("users.activate.resend_verification_email.email_sent", email: user.email))
        expect(response).to redirect_to(root_path(user))
      end
    end

    context 'when the user has already verified their email' do
      before { user.update!(email_verified_at: Time.zone.now) }

      it 'does not send mail and shows an alert' do
        post :resend_verification_email
        expect(flash[:alert]).to eq(I18n.t('users.activate.resend_verification_email.already_verified'))
        expect(response).to redirect_to(root_path(user))
      end
    end
  end
  describe '#new' do
    let(:user) { create(:user) }
    let(:token) { user.send(:set_reset_password_token) }

    before { allow(controller).to receive(:trust_device) }

    context 'when the token is ok' do
      before { get :new, params: { token: token } }

      it do
        expect(user.reload.email_verified_at).to be_present
      end
    end

    context 'when the token is bad' do
      before { get :new, params: { token: 'bad' } }

      it { expect(controller).not_to have_received(:trust_device) }
    end
  end

  describe '#create' do
    let!(:user) { create(:user) }
    let(:token) { user.send(:set_reset_password_token) }
    let(:password) { '{another-password-ok?}' }

    before do
      allow(controller).to receive(:trust_device)
      post :create, params: { user: { reset_password_token: token, password: password } }
    end

    context 'when the token is ok' do
      it do
        expect(user.reload.valid_password?(password)).to be true
        expect(controller).not_to have_received(:trust_device)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when the token is ok and user is instructeur' do
      let!(:user) { create(:instructeur).user }

      it 'trusts the device' do
        expect(user.reload.valid_password?(password)).to be true
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when the token is ok and user is admin' do
      let(:admin) { administrateurs(:default_admin) }
      let!(:user) { admin.user }

      it 'trusts the device because admin has an instructeur profile' do
        expect(user.reload.valid_password?(password)).to be true
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when the token is ok and user is gestionnaire' do
      let(:gestionnaire) { create(:gestionnaire) }
      let!(:user) { gestionnaire.user }

      it 'does not trust the device' do
        expect(user.reload.valid_password?(password)).to be true
        expect(controller).not_to have_received(:trust_device)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when the token is bad' do
      let(:token) { 'bad' }

      it do
        expect(user.reload.valid_password?(password)).to be false
        expect(controller).not_to have_received(:trust_device)
        expect(response).to redirect_to(users_activate_path(token: token))
      end
    end

    context 'when the password is not strong' do
      let(:password) { 'password-ok?' }

      it do
        expect(user.reload.valid_password?(password)).to be false
        expect(controller).not_to have_received(:trust_device)
        expect(response).to redirect_to(users_activate_path(token: token))
      end
    end
  end

  describe '#confirm_email' do
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, user: user) }

    before { user.invite_tiers!(dossier) }

    context 'when the confirmation token is valid' do
      before do
        get :confirm_email, params: { token: user.confirmation_token }
        user.reload
      end

      it 'updates the email_verified_at' do
        expect(user.email_verified_at).to be_present
        expect(user.confirmation_token).to be_present
      end

      it 'redirects to root path with a success notice' do
        expect(response).to redirect_to(root_path(user))
        expect(flash[:notice]).to eq(I18n.t('users.activate.confirm_email.email_verified'))
      end
    end

    context 'when the confirmation token is valid but already used' do
      before do
        get :confirm_email, params: { token: user.confirmation_token }
        get :confirm_email, params: { token: user.confirmation_token }
      end

      it 'redirects to root path with an explanation notice' do
        expect(response).to redirect_to(root_path(user))
        expect(flash[:notice]).to eq(I18n.t('users.activate.confirm_email.already_verified'))
      end
    end

    context 'when the confirmation token is too old or not valid' do
      subject { get :confirm_email, params: { token: user.confirmation_token } }

      before do
        user.update!(confirmation_sent_at: 3.days.ago)
      end

      it 'redirects to root path with an explanation notice and it send a new link if user present' do
        expect { subject }.to have_enqueued_mail(UserMailer, :resend_confirmation_email)
        expect(response).to redirect_to(root_path(user))
        expect(flash[:alert]).to eq(I18n.t("users.activate.confirm_email.expired_link", email: user.email))
      end
    end
  end
end
