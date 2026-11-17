# frozen_string_literal: true

describe Users::ProfilPasswordsController, type: :controller do
  include ActiveJob::TestHelper

  let(:user) { users.usager }
  let(:current_password) { users.default_password }
  let(:new_password) { 'un nouveau mot de passe bien long !' }

  before { sign_in(user) }

  describe '#edit' do
    render_views

    it 'renders the form' do
      get :edit

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Mot de passe actuel')
      expect(response.body).to include('Réinitialiser mon mot de passe')
      expect(response.body).not_to include('Ce mot de passe concerne uniquement votre compte local.')
    end

    context 'when the account is linked to FranceConnect' do
      before { create(:france_connect_information, user:) }

      it 'says the password is not FranceConnect’s' do
        get :edit

        expect(response.body).to include('Ce mot de passe concerne uniquement votre compte local. Il sera utilisé lors de vos connexions avec votre adresse électronique, et non via FranceConnect.')
      end
    end

    context 'when the account is linked to ProConnect' do
      before { create(:pro_connect_information, user:) }

      it 'says the password is not ProConnect’s' do
        get :edit

        expect(response.body).to include('Ce mot de passe concerne uniquement votre compte local. Il sera utilisé lors de vos connexions avec votre adresse électronique, et non via ProConnect.')
      end
    end

    context 'when the account is linked to both' do
      before do
        create(:france_connect_information, user:)
        create(:pro_connect_information, user:)
      end

      it 'says the password is neither FranceConnect’s nor ProConnect’s' do
        get :edit

        expect(response.body).to include('Ce mot de passe concerne uniquement votre compte local. Il sera utilisé lors de vos connexions avec votre adresse électronique, et non via FranceConnect ou ProConnect.')
      end
    end
  end

  context 'when ProConnect is required for the administrateur' do
    let(:user) { administrateurs.default.user }

    before do
      allow(ProConnectService).to receive(:enabled?).and_return(true)
      user.administrateur.update!(pro_connect_required_at: Time.zone.now)
    end

    it 'does not show the page' do
      get :edit

      expect(response).to redirect_to(profil_path)
      expect(flash.alert).to eq(I18n.t('users.profil_passwords.ensure_password_login_allowed.pro_connect_required'))
    end

    it 'does not change the password' do
      expect {
        patch :update, params: { user: { current_password:, password: new_password, password_confirmation: new_password } }
      }.not_to change { user.reload.encrypted_password }
    end

    it 'does not sign the user out' do
      post :forgot

      expect(controller.current_user).to eq(user)
    end
  end

  describe '#update' do
    subject(:update_request) do
      patch :update, params: { user: { current_password: submitted_current, password: submitted_new, password_confirmation: submitted_confirmation } }
    end

    let(:submitted_current) { current_password }
    let(:submitted_new) { new_password }
    let(:submitted_confirmation) { new_password }

    context 'with valid params' do
      it 'changes the password' do
        expect { update_request }.to change { user.reload.encrypted_password }
        expect(response).to redirect_to(profil_path)
      end

      it 'notifies the user' do
        expect { update_request }.to have_enqueued_mail(UserMailer, :password_changed)
      end
    end

    shared_examples 'a rejected change' do
      it 'does not change the password and re-renders the form' do
        expect { update_request }.not_to change { user.reload.encrypted_password }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not notify the user' do
        expect { update_request }.not_to have_enqueued_mail(UserMailer, :password_changed)
      end
    end

    context 'with a wrong current password, rendering the page' do
      render_views

      let(:submitted_current) { 'ce n’est pas le bon mot de passe' }

      it 'shows the error under the field' do
        update_request

        expect(response.body).to include('est incorrect')
      end
    end

    context 'with a wrong current password' do
      let(:submitted_current) { 'ce n’est pas le bon mot de passe' }

      it_behaves_like 'a rejected change'

      it 'also shows the error at the top of the page' do
        update_request

        expect(flash.now[:alert]).to contain_exactly(a_string_including('est incorrect. Saisir votre mot de passe actuel'))
      end
    end

    context 'with a blank current password' do
      let(:submitted_current) { '' }

      it_behaves_like 'a rejected change'
    end

    context 'with a blank new password' do
      let(:submitted_new) { '' }
      let(:submitted_confirmation) { '' }

      it_behaves_like 'a rejected change'

      it 'also shows the error at the top of the page' do
        update_request

        expect(flash.now[:alert]).to contain_exactly(a_string_including('est vide. Saisir un nouveau mot de passe'))
      end
    end

    context 'with a mismatched confirmation' do
      let(:submitted_confirmation) { 'autre chose de tout aussi long' }

      it_behaves_like 'a rejected change'
    end

    context 'with the current password as the new one' do
      let(:submitted_new) { current_password }
      let(:submitted_confirmation) { current_password }

      it_behaves_like 'a rejected change'

      it 'tells the user to pick a different password' do
        update_request

        expect(controller.current_user.errors).to be_of_kind(:password, :same_as_current)
      end
    end

    context 'with a wrong current password and the real one as the new one' do
      let(:submitted_current) { 'ce n’est pas le bon mot de passe' }
      let(:submitted_new) { current_password }
      let(:submitted_confirmation) { current_password }

      it 'only reports the wrong current password' do
        update_request

        expect(controller.current_user.errors).to be_of_kind(:current_password, :invalid)
        expect(controller.current_user.errors).not_to be_of_kind(:password, :same_as_current)
      end
    end

    context 'with a weak new password' do
      let(:submitted_new) { '000000000000' }
      let(:submitted_confirmation) { '000000000000' }

      it_behaves_like 'a rejected change'
    end
  end

  describe '#forgot' do
    it 'signs the user out and sends them to the reset form' do
      post :forgot

      expect(controller.current_user).to be_nil
      expect(session['warden.user.user.key']).to be_nil
      expect(response).to redirect_to(new_user_password_path)
      expect(response).to have_http_status(:see_other)
    end
  end

  describe '#nav_bar_profile' do
    let(:user) { create(:instructeur).user }

    it 'honours the context parameter' do
      get :edit, params: { context: 'instructeur' }
      expect(controller.nav_bar_profile).to eq(:instructeur)
    end
  end
end
