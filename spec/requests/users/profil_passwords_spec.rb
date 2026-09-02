# frozen_string_literal: true

describe 'Users::ProfilPasswords', type: :request do
  before { login_as user, scope: :user }

  # Le layout complet est rendu ici parce que la barre de navigation partagée
  # appelle current_page?(controller: 'administrateurs/procedures'). Rails
  # résout ce contrôleur relativement au contrôleur courant : un namespace à
  # trois niveaux le ferait chercher users/administrateurs/procedures et lever
  # une UrlGenerationError.
  describe 'GET /profil/mot-de-passe' do
    context 'as a usager' do
      let(:user) { users.usager }

      it 'renders' do
        get edit_profil_password_path

        expect(response).to have_http_status(:ok)
      end
    end

    context 'in the administrateur context' do
      let(:user) { administrateurs.default.user }

      it 'renders the administrateur navigation' do
        get edit_profil_password_path(context: 'administrateur')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(admin_procedures_path)
      end
    end

    context 'in the instructeur context' do
      let(:user) { instructeurs.default.user }

      it 'renders the instructeur navigation' do
        get edit_profil_password_path(context: 'instructeur')

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
