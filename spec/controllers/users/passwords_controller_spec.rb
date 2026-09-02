# frozen_string_literal: true

describe Users::PasswordsController, type: :controller do
  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "update" do
    context "unified login" do
      let(:administrateur) { create(:administrateur, email: 'unique@plop.com', password: 'mot de passe complexe') }
      let(:user) { administrateur.instructeur.user }

      before do
        @token = user.send(:set_reset_password_token)
        administrateur # make sure it's created
      end

      it "also signs instructeur in" do
        put :update, params: {
          user: {
            reset_password_token: @token,
            password: "mot de passe super secret",
            password_confirmation: "mot de passe super secret",
          },
        }
        expect(subject.current_user).to eq(user)
        expect(subject.current_instructeur.email).to eq(administrateur.email)
      end

      it "also signs administrateur in" do
        put :update, params: {
          user: {
            reset_password_token: @token,
            password: "mot de passe super secret",
            password_confirmation: "mot de passe super secret",
          },
        }
        expect(subject.current_user).to eq(user)
        expect(subject.current_administrateur).to eq(administrateur)
      end

      it "marks user's email as verified" do
        expect do
          put :update, params: {
            user: {
              reset_password_token: @token,
              password: "mot de passe super secret",
              password_confirmation: "mot de passe super secret",
            },
          }
        end.to change { user.reload.email_verified_at }
          .from(nil).to(anything)
      end
    end
  end

  describe '#reset_link_sent' do
    let(:email) { 'test@example.com' }

    it 'displays the page' do
      crypted_email = controller.message_encryptor_service.encrypt_and_sign(email, purpose: :reset_password)

      get 'reset_link_sent', params: { email: crypted_email }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template('reset_link_sent')
      expect(assigns(:email)).to eq email
    end

    it 'when message was only signed, displays the page' do
      signed_email = ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base).generate(email, purpose: :reset_password)

      get 'reset_link_sent', params: { email: signed_email }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template('reset_link_sent')
      expect(assigns(:email)).to eq email
    end

    context 'when signed email is invalid' do
      it "does not fail" do
        get 'reset_link_sent', params: { email: "invalid.message" }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template('reset_link_sent')
        expect(assigns(:email)).to be_nil
      end
    end
  end

  describe 'password change notification' do
    include ActiveJob::TestHelper

    let(:user) { create(:user) }

    context 'when the reset succeeds' do
      let(:token) { user.send(:set_reset_password_token) }

      it 'notifies the user' do
        expect { put :update, params: { user: { reset_password_token: token, password: SECURE_PASSWORD, password_confirmation: SECURE_PASSWORD } } }
          .to have_enqueued_mail(UserMailer, :password_changed)
      end
    end

    context 'when the token is invalid' do
      it 'does not notify anyone' do
        expect { put :update, params: { user: { reset_password_token: 'nope', password: SECURE_PASSWORD, password_confirmation: SECURE_PASSWORD } } }
          .not_to have_enqueued_mail(UserMailer, :password_changed)
      end
    end
  end
end
