# frozen_string_literal: true

describe Manager::ChampMatchingResultsController, type: :controller do
  let(:super_admin) { create(:super_admin, :with_otp) }
  before { sign_in super_admin }

  render_views

  describe 'GET #show' do
    let(:left) { create(:procedure, :published, libelle: 'Permis de construire', public_type_de_champs: [{ type: :text, libelle: 'Votre adresse' }]) }
    let(:right) { create(:procedure, :published, libelle: 'Aide à la rénovation', public_type_de_champs: [{ type: :text, libelle: 'Adresse du domicile' }]) }
    let(:match) { TypeDeChampMatch.sole }

    before do
      stub_const('ChampMatchingConcern::USERS_FLOOR', 1)

      user = create(:user)
      { left => '12 rue du Pont', right => '12, Rue du PONT' }.each do |procedure, value|
        create(:dossier, :en_construction, procedure:, user:).champ_data.find { !it.private? }.update_column(:value, value)
      end

      ProcedureUserOverlap.refresh_within([left.id, right.id])
      ProcedureUserOverlap.find_each(&:refresh_champ_matches!)
    end

    let(:administrateur) { create(:administrateur, email: super_admin.email) }

    def administer(*procedures, manager: nil)
      procedures.each { AdministrateursProcedure.create!(administrateur:, procedure: it, manager:) }
    end

    shared_examples 'the values show' do
      it 'montre les valeurs saisies' do
        get :show, params: { id: "#{match.id}-#{left.id}" }

        expect(response.body).to include('12 rue du Pont', '12, Rue du PONT')
      end
    end

    context 'when the super admin only opened manager sessions on both' do
      before { administer(left, right, manager: true) }

      it_behaves_like 'the values show'
    end

    context 'when the super admin administers both procedures' do
      before { administer(left, right) }

      it_behaves_like 'the values show'

      it 'montre la ligne, puis les valeurs saisies et normalisées de chaque usager' do
        get :show, params: { id: "#{match.id}-#{right.id}" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Aide à la rénovation', 'Adresse du domicile', '12, Rue du PONT', '12 rue du pont')
        expect(response.body.index('12, Rue du PONT')).to be < response.body.index('12 rue du Pont')
      end

      it 'relie chaque valeur au dossier où elle a été saisie' do
        get :show, params: { id: "#{match.id}-#{left.id}" }

        [left, right].each do |procedure|
          expect(response.body).to include(instructeur_dossier_path(procedure_id: procedure.id, dossier_id: procedure.dossiers.sole.id))
        end
      end

      it 'filtre les comparaisons par verdict' do
        get :show, params: { id: "#{match.id}-#{left.id}", verdict: 'differing' }

        expect(response.body).not_to include('12 rue du Pont')
      end
    end

    shared_examples 'the values stay hidden' do
      it 'montre la ligne mais aucune valeur saisie' do
        get :show, params: { id: "#{match.id}-#{left.id}" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Votre adresse', 'Adresse du domicile', 'administrateurs des deux démarches')
        expect(response.body).not_to include('12 rue du Pont')
        expect(response.body).not_to include('12, Rue du PONT')
      end
    end

    context 'when the super admin administers neither procedure' do
      it_behaves_like 'the values stay hidden'
    end

    context 'when the super admin administers only one of them' do
      before { administer(left) }

      it_behaves_like 'the values stay hidden'
    end
  end

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

    it 'rend chaque ligne cliquable vers le détail de son appariement' do
      get :index

      match = TypeDeChampMatch.sole
      expect(response.body).to include(manager_champ_matching_result_path("#{match.id}-#{match.left_procedure_id}"))
      expect(response.body).to include(manager_champ_matching_result_path("#{match.id}-#{match.right_procedure_id}"))
    end

    it 'pagine les démarches, sans couper une démarche de ses partenaires' do
      get :index, params: { per_page: 1 }

      expect(response.body.scan('Votre adresse').size).to eq(1)
    end
  end
end
