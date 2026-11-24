# frozen_string_literal: true

describe 'Users::DossiersController#create_commentaire', type: :request do
  before { login_as(users.usager, scope: :user) }

  it 'rejects a commentaire that is not a hash' do
    post commentaire_dossier_path(dossiers.en_construction), params: { commentaire: "{'body': 'Bonjour'}" }

    expect(response).to have_http_status(:bad_request)
  end
end
