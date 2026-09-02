# frozen_string_literal: true

describe Users::ProfilPasswordsController, type: :controller do
  include ActiveJob::TestHelper

  let(:user) { users.usager }
  let(:current_password) { users.default_password }
  let(:new_password) { 'un nouveau mot de passe bien long !' }

  before { sign_in(user) }

  # La page est rendue ici parce que l'encart FranceConnect et l'affichage des
  # erreurs sous les champs sont des exigences de conception qu'aucune autre
  # spec ne couvre.
  describe '#edit' do
    render_views

    it 'renders the form' do
      get :edit

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Mot de passe actuel')
      expect(response.body).to include('Réinitialiser mon mot de passe')
    end

    context 'when the account is linked to FranceConnect' do
      before { create(:france_connect_information, user: user) }

      it 'reassures the user that FranceConnect is not affected' do
        get :edit

        expect(response.body).to include('Votre connexion FranceConnect n’est pas concernée')
      end
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

      # `bypass_sign_in` n'appelle pas warden.set_user : il ne réécrit que le
      # session serializer. Asserter sur controller.current_user ne prouverait
      # donc rien, l'objet en mémoire restant le même. C'est le sel stocké en
      # session qui doit suivre le nouveau mot de passe.
      it 'refreshes the session so the user stays signed in' do
        update_request
        expect(session['warden.user.user.key'].last).to eq(user.reload.authenticatable_salt)
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
    end

    # Cas d'un compte créé via FranceConnect : son propriétaire n'a pas de mot
    # de passe à saisir.
    context 'with a blank current password' do
      let(:submitted_current) { '' }

      it_behaves_like 'a rejected change'
    end

    # Devise supprime password et password_confirmation des params quand le
    # nouveau mot de passe est vide, puis update({}) renvoie true : sans la
    # garde du contrôleur, ce cas produirait un faux succès et une fausse
    # alerte de sécurité.
    context 'with a blank new password' do
      let(:submitted_new) { '' }
      let(:submitted_confirmation) { '' }

      it_behaves_like 'a rejected change'
    end

    context 'with a mismatched confirmation' do
      let(:submitted_confirmation) { 'autre chose de tout aussi long' }

      it_behaves_like 'a rejected change'
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
