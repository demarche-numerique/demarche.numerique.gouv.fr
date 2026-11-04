# frozen_string_literal: true

describe Manager::ChampMatchingResultsController, type: :controller do
  let(:super_admin) { create(:super_admin, :with_otp) }
  before { sign_in super_admin }

  render_views

  describe 'GET #index' do
    before do
      left = create(:procedure, :published, libelle: 'Permis de construire', public_type_de_champs: [{ type: :text, libelle: 'Votre adresse' }])
      right = create(:procedure, :published, libelle: 'Aide à la rénovation', public_type_de_champs: [{ type: :text, libelle: 'Adresse du domicile' }])
      ProcedureUserOverlap.create!(left_procedure_id: left.id, right_procedure_id: right.id,
                                   common_users_count: 80)
      TypeDeChampMatch.create!(left_procedure_id: left.id, left_stable_id: left.published_revision.public_root_type_de_champs.sole.stable_id,
                               right_procedure_id: right.id, right_stable_id: right.published_revision.public_root_type_de_champs.sole.stable_id,
                               matching_users_count: 78, common_users_count: 80)
    end

    it 'affiche un tableau par démarche, avec ses démarches partenaires' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Permis de construire', 'Aide à la rénovation', 'Votre adresse', 'Adresse du domicile', '0.91')
      expect(response.body.scan('Votre adresse').size).to eq(2)
    end

    it 'pagine les démarches, sans couper une démarche de ses partenaires' do
      get :index, params: { per_page: 1 }

      expect(response.body.scan('Votre adresse').size).to eq(1)
    end
  end
end
