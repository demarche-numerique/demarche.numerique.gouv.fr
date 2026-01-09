# frozen_string_literal: true

describe Administrateurs::ProceduresController, type: :controller do
  include Logic

  let(:admin) { administrateurs(:default_admin) }
  let(:administrateur_2) { create(:administrateur) }
  let(:administrateur_3) { create(:administrateur) }
  let(:instructeur_2) { create(:instructeur) }
  let(:bad_procedure_id) { 100000 }

  let(:path) { 'ma-jolie-demarche' }
  let(:libelle) { 'Démarche de test' }
  let(:description) { 'Description de test' }
  let(:organisation) { 'Organisation de test' }
  let(:ministere) { create(:zone) }
  let(:cadre_juridique) { 'cadre juridique' }
  let(:duree_conservation_dossiers_dans_ds) { 3 }
  let(:monavis_embed) { nil }
  let(:lien_site_web) { 'http://mon-site.gouv.fr' }
  let(:zone) { create(:zone) }
  let(:zone_ids) { [zone.id] }
  let!(:tag1) { ProcedureTag.create(name: 'Aao') }
  let!(:tag2) { ProcedureTag.create(name: 'Accompagnement') }

  describe '#apercu' do
    subject { get :apercu, params: { id: procedure.id } }

    before do
      sign_in(admin.user)
    end

    context 'all tdc can be rendered' do
      render_views

      let(:procedure) { create(:procedure, :with_all_champs) }

      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(procedure.dossiers.visible_by_user).to be_empty
        expect(procedure.dossiers.for_procedure_preview).not_to be_empty
      end
    end

    context 'when the draft is invalid' do
      let(:procedure) { create(:procedure) }

      before do
        allow_any_instance_of(ProcedureRevision).to receive(:invalid?).and_return(true)
      end

      it do
        subject
        expect(response).to redirect_to(champs_admin_procedure_path(procedure))
        expect(flash[:alert]).to be_present
      end
    end
  end

  let(:procedure_params) {
    {
      path: path,
      libelle: libelle,
      description: description,
      organisation: organisation,
      ministere: ministere,
      cadre_juridique: cadre_juridique,
      duree_conservation_dossiers_dans_ds: duree_conservation_dossiers_dans_ds,
      monavis_embed: monavis_embed,
      zone_ids: zone_ids,
      procedure_tag_names: ['Aao', 'Accompagnement'],
    }
  }

  let(:procedure_params_not_creatable) {
    {
      lien_site_web: lien_site_web,
      robots_indexable: "0",
    }
  }

  before do
    sign_in(admin.user)
  end

  describe 'GET #index' do
    subject { get :index }

    it { expect(response.status).to eq(200) }
  end

  describe 'GET #index with sorting and pagination' do
    before do
      create(:procedure, administrateur: admin)
      admin.reload
    end

    subject {
      get :index, params: {
        'statut': 'publiees',
      }
    }

    it { expect(subject.status).to eq(200) }
  end

  describe 'GET #all' do
    let!(:draft_procedure)     { create(:procedure) }
    let!(:published_procedure) { create(:procedure_with_dossiers, :published, dossiers_count: 2) }
    let!(:closed_procedure)    { create(:procedure, :closed) }

    subject { get :all }

    it { expect(subject.status).to eq(200) }

    context 'for export' do
      subject { get :all, format: :xlsx }

      it 'exports result in xlsx' do
        allow(ProcedureDetail).to receive(:to_xlsx)
        subject
        expect(ProcedureDetail).to have_received(:to_xlsx)
      end
    end

    it 'displays published/closed procedures but not draft procedures' do
      subject
      expect(assigns(:procedures).any? { |p| p.id == published_procedure.id }).to be_truthy
      expect(assigns(:procedures).any? { |p| p.id == closed_procedure.id }).to be_truthy
      expect(assigns(:procedures).any? { |p| p.id == draft_procedure.id }).to be_falsey
    end

    context 'for default admin zones' do
      let(:zone1) { create(:zone) }
      let(:zone2) { create(:zone) }
      let!(:procedure1) { create(:procedure, :published, :new_administrateur, zones: [zone1]) }
      let!(:procedure2) { create(:procedure, :published, :new_administrateur, zones: [zone1, zone2]) }
      let!(:admin_procedure) { create(:procedure, :published, zones: [zone2], administrateur: admin) }

      subject { get :all, params: { zone_ids: :admin_default } }

      it 'display only procedures for specified zones' do
        subject
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == admin_procedure.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure1.id }).to be_falsey
      end
    end

    context "for specific zones" do
      let(:zone1) { create(:zone) }
      let(:zone2) { create(:zone) }
      let!(:procedure1) { create(:procedure, :published, zones: [zone1]) }
      let!(:procedure2) { create(:procedure, :published, zones: [zone1, zone2]) }

      subject { get :all, params: { zone_ids: [zone2.id] } }

      it 'display only procedures for specified zones' do
        subject
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure1.id }).to be_falsey
      end

      context "without zones" do
        let!(:procedure) { create(:procedure, :published, zones: []) }
        subject { get :all }

        it 'displays procedures without zones' do
          subject
          expect(assigns(:procedures).any? { |p| p.id == procedure.id }).to be_truthy
        end
      end
    end

    context 'for specific status' do
      let!(:procedure1) { create(:procedure, :published) }
      let!(:procedure2) { create(:procedure, :closed) }

      it 'display only published procedures' do
        get :all, params: { statuses: ['publiee'] }
        expect(assigns(:procedures).any? { |p| p.id == procedure1.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_falsey
      end

      it 'display only closed procedures' do
        get :all, params: { statuses: ['close'] }
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure1.id }).to be_falsey
      end
    end

    context 'after specific date' do
      let(:after) { Date.new(2022, 06, 30) }
      let!(:procedure1) { create(:procedure, :published, published_at: after + 1.day) }
      let!(:procedure2) { create(:procedure, :published, published_at: after + 2.days) }
      let!(:procedure3) { create(:procedure, :published, published_at: after - 1.day) }

      it 'display only procedures published after specific date' do
        get :all, params: { from_publication_date: after }
        expect(assigns(:procedures).any? { |p| p.id == procedure1.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure3.id }).to be_falsey
      end
    end

    context 'only_not_hidden_as_template' do
      let!(:procedure1) { create(:procedure, :published) }
      let!(:procedure2) { create(:procedure, :published, hidden_at_as_template: Time.zone.now) }
      let!(:procedure3) { create(:procedure, :published) }

      it 'display only procedures which are not hidden as template' do
        get :all
        expect(assigns(:procedures).any? { |p| p.id == procedure1.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_falsey
        expect(assigns(:procedures).any? { |p| p.id == procedure3.id }).to be_truthy
      end
    end

    context 'with specific service' do
      let(:requested_siret) { '13001501900024' }
      let(:another_siret) { '11000004900012' }
      let(:requested_service) { create(:service, siret: requested_siret) }
      let(:another_service) { create(:service, siret: another_siret) }
      let!(:procedure1) { create(:procedure, :published, service: another_service) }
      let!(:procedure2) { create(:procedure, :published, service: requested_service) }
      it 'display only procedures with specific service (identified by siret)' do
        get :all, params: { service_siret: requested_siret }
        expect(assigns(:procedures).any? { |p| p.id == procedure1.id }).to be_falsey
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_truthy
      end
    end

    context 'with a siret which does not identify a service' do
      let(:requested_siret) { '13001501900024' }
      let(:another_siret) { '11000004900012' }
      let(:another_service) { create(:service, siret: another_siret) }
      let!(:procedure1) { create(:procedure, :published, service: another_service) }
      it 'displays none procedure' do
        get :all, params: { service_siret: requested_siret }
        expect(assigns(:procedures)).to be_empty
      end
    end

    context 'with service departement' do
      let(:service) { create(:service, departement: '63') }
      let(:service2) { create(:service, departement: '75') }
      let!(:procedure) { create(:procedure, :published, service: service) }
      let!(:procedure2) { create(:procedure, :published, service: service2) }

      it 'returns procedures with correct departement' do
        get :all, params: { service_departement: '63' }
        expect(assigns(:procedures).any? { |p| p.id == procedure.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_falsey
      end
    end

    context 'only for individual' do
      let!(:procedure) { create(:procedure, :published, for_individual: true) }
      let!(:procedure2) { create(:procedure, :published, for_individual: false) }
      it 'returns procedures with specifi type of usager' do
        get :all, params: { kind_usagers: ['individual'] }
        expect(assigns(:procedures).any? { |p| p.id == procedure.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_falsey
      end
    end

    context 'only for entreprise' do
      let!(:procedure) { create(:procedure, :published, for_individual: true) }
      let!(:procedure2) { create(:procedure, :published, for_individual: false) }
      it 'returns procedures with specifi type of usager' do
        get :all, params: { kind_usagers: ['personne_morale'] }
        expect(assigns(:procedures).any? { |p| p.id == procedure.id }).to be_falsey
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_truthy
      end
    end

    context 'for individual and entreprise' do
      let!(:procedure) { create(:procedure, :published, for_individual: true) }
      let!(:procedure2) { create(:procedure, :published, for_individual: false) }
      it 'returns procedures with specifi type of usager' do
        get :all, params: { kind_usagers: ['individual', 'personne_morale'] }
        expect(assigns(:procedures).any? { |p| p.id == procedure.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_truthy
      end
    end

    context 'with specific tag' do
      let!(:tag_environnement) { ProcedureTag.create(name: 'environnement') }
      let!(:tag_diplomatie) { ProcedureTag.create(name: 'diplomatie') }
      let!(:tag_football) { ProcedureTag.create(name: 'football') }

      let!(:procedure) do
        procedure = create(:procedure, :published)
        procedure.procedure_tags << [tag_environnement, tag_diplomatie]
        procedure
      end

      it 'returns procedure who contains at least one tag included in params' do
        get :all, params: { tags: ['environnement'] }
        expect(assigns(:procedures).find { |p| p.id == procedure.id }).to be_present
      end

      it 'returns procedures who contains all tags included in params' do
        get :all, params: { tags: ['environnement', 'diplomatie'] }
        expect(assigns(:procedures).find { |p| p.id == procedure.id }).to be_present
      end

      it 'returns the procedure when at least one tag is include' do
        get :all, params: { tags: ['environnement', 'diplomatie', 'football'] }
        expect(assigns(:procedures).find { |p| p.id == procedure.id }).to be_present
      end

      it 'does not return procedure not having the queried tag' do
        get :all, params: { tags: ['football'] }
        expect(assigns(:procedures)).to be_empty
      end
    end

    context 'with template procedures' do
      let!(:template_procedure) { create(:procedure, :published, template: true) }
      let!(:other_procedure) { create(:procedure, :published, template: false) }

      it 'identifies a procedure as a template' do
        get :all, params: { template: '1' }
        expect(assigns(:procedures).any? { |p| p.id == template_procedure.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == other_procedure.id }).to be_falsey
      end
    end

    context 'with libelle search' do
      let!(:procedure1) { create(:procedure, :published, libelle: 'Demande de subvention') }
      let!(:procedure2) { create(:procedure, :published, libelle: "Fonds d’aide public « Prime Entrepreneurs des Quartiers »") }
      let!(:procedure3) { create(:procedure, :published, libelle: "Hackaton pour entrepreneurs en résidence") }

      it 'returns procedures with specific terms in libelle' do
        get :all, params: { libelle: 'entrepreneur' }
        expect(assigns(:procedures).any? { |p| p.id == procedure2.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure3.id }).to be_truthy
        expect(assigns(:procedures).any? { |p| p.id == procedure1.id }).to be_falsey
      end
    end
  end

  describe 'GET #administrateurs' do
    let!(:draft_procedure)     { create(:procedure, administrateur: admin3) }
    let!(:published_procedure) { create(:procedure_with_dossiers, :published, dossiers_count: 2, administrateur: admin1) }
    let!(:antoher_published_procedure_for_admin1) { create(:procedure_with_dossiers, :published, dossiers_count: 2, administrateur: admin1) }
    let!(:antoher_published_procedure) { create(:procedure_with_dossiers, :published, dossiers_count: 2, administrateur: admin4) }
    let!(:closed_procedure) { create(:procedure, :closed, administrateur: admin2) }
    let(:admin1) { create(:administrateur, email: 'jesuis.surmene@education.gouv.fr') }
    let(:admin2) { create(:administrateur, email: 'jesuis.alecoute@social.gouv.fr') }
    let(:admin3) { create(:administrateur, email: 'gerard.lambert@interieur.gouv.fr') }
    let(:admin4) { create(:administrateur, email: 'jack.lang@culture.gouv.fr') }

    it 'displays admins of the procedures' do
      get :administrateurs
      expect(assigns(:admins)).to include(admin1)
      expect(assigns(:admins)).to include(admin2)
      expect(assigns(:admins)).to include(admin4)
      expect(assigns(:admins)).not_to include(admin3)
    end

    context 'with email search' do
      it 'returns procedures with specific terms in libelle' do
        get :administrateurs, params: { email: 'jesuis' }
        expect(assigns(:admins)).to include(admin1)
        expect(assigns(:admins)).to include(admin2)
        expect(assigns(:admins)).not_to include(admin3)
        expect(assigns(:admins)).not_to include(admin4)
      end
    end

    context 'only_not_hidden_as_template' do
      before do
        published_procedure.update(hidden_at_as_template: Time.zone.now)
        closed_procedure.update(hidden_at_as_template: Time.zone.now)
        antoher_published_procedure.update(hidden_at_as_template: Time.zone.now)
      end

      it 'displays admins of the procedures' do
        get :administrateurs
        expect(assigns(:admins)).to include(admin1)
        expect(assigns(:admins)).not_to include(admin2)
        expect(assigns(:admins)).not_to include(admin4)
        expect(assigns(:admins)).not_to include(admin3)
        expect(assigns(:admins)[0].procedures).not_to include(published_procedure)
        expect(assigns(:admins)[0].procedures).to include(antoher_published_procedure_for_admin1)
      end
    end
  end

  describe 'POST #search' do
    before do
      stub_const("Administrateurs::ProceduresController::SIGNIFICANT_DOSSIERS_THRESHOLD", 2)
    end

    let(:query) { 'Procedure' }

    subject { post :search, params: { query: query }, format: :turbo_stream }
    let(:grouped_procedures) { subject; assigns(:grouped_procedures) }
    let(:response_procedures) { grouped_procedures.map { |_o, procedures| procedures }.flatten }

    describe 'selecting' do
      let!(:large_draft_procedure)     { create(:procedure_with_dossiers, dossiers_count: 2) }
      let!(:large_published_procedure) { create(:procedure_with_dossiers, :published, dossiers_count: 2) }
      let!(:large_closed_procedure)  { create(:procedure_with_dossiers, :closed,  dossiers_count: 2) }
      let!(:small_closed_procedure)  { create(:procedure_with_dossiers, :closed,  dossiers_count: 1) }

      it 'displays expected procedures' do
        # published and closed procedures' do
        expect(response_procedures).to include(large_published_procedure)
        expect(response_procedures).to include(large_closed_procedure)

        # doesn’t display procedures without a significant number of dossiers'
        expect(response_procedures).not_to include(small_closed_procedure)

        # doesn’t display draft procedures'
        expect(response_procedures).not_to include(large_draft_procedure)
      end
    end

    describe 'grouping' do
      let(:service_1) { create(:service, nom: 'DDT des Vosges') }
      let(:service_2) { create(:service, nom: 'DDT du Loiret') }
      let!(:procedure_with_service_1)  { create(:procedure_with_dossiers, :published, organisation: nil, service: service_1, dossiers_count: 2) }
      let!(:procedure_with_service_2)  { create(:procedure_with_dossiers, :published, organisation: nil, service: service_2, dossiers_count: 2) }
      let!(:procedure_without_service) { create(:procedure_with_dossiers, :published, service: nil, organisation: 'DDT du Loiret', dossiers_count: 2) }

      it 'groups procedures with services as well as procedures with organisations' do
        expect(grouped_procedures.length).to eq 2
        expect(grouped_procedures.find { |o, _p| o == 'DDT des Vosges' }.last).to contain_exactly(procedure_with_service_1)
        expect(grouped_procedures.find { |o, _p| o == 'DDT du Loiret'  }.last).to contain_exactly(procedure_with_service_2, procedure_without_service)
      end
    end

    describe 'searching' do
      let!(:matching_procedure) { create(:procedure_with_dossiers, :published, dossiers_count: 2, libelle: 'éléctriCITE') }
      let!(:unmatching_procedure_cause_hidden_as_template) { create(:procedure_with_dossiers, :published, dossiers_count: 2, libelle: 'éléctriCITE', hidden_at_as_template: Time.zone.now) }
      let!(:unmatching_procedure) { create(:procedure_with_dossiers, :published, dossiers_count: 2, libelle: 'temoin') }

      let(:query) { 'ELECTRIcité' }

      it 'is case insentivite and unaccented' do
        expect(response_procedures).to include(matching_procedure)
        expect(response_procedures).not_to include(unmatching_procedure)

        # hide procedure if it is hidden as template
        expect(response_procedures).not_to include(unmatching_procedure_cause_hidden_as_template)
      end
    end
  end

  describe 'GET #edit' do
    let(:published_at) { nil }
    let(:procedure) { create(:procedure, administrateur: admin, published_at: published_at) }
    let(:procedure_id) { procedure.id }

    subject { get :edit, params: { id: procedure_id } }

    context 'when user is not connected' do
      before do
        sign_out(admin.user)
      end

      it { is_expected.to redirect_to new_user_session_path }
    end

    context 'when user is connected' do
      context 'when procedure exist' do
        let(:procedure_id) { procedure.id }
        it { is_expected.to have_http_status(:success) }
      end

      context 'when procedure is published' do
        let(:published_at) { Time.zone.now }
        it { is_expected.to have_http_status(:success) }
      end

      context 'when procedure doesn’t exist' do
        let(:procedure_id) { bad_procedure_id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'GET #zones' do
    let(:procedure) { create(:procedure, administrateur: admin) }
    let(:procedure_id) { procedure.id }

    let(:last_zone) { create(:zone, labels: [{ designated_on: '1981-05-08', name: 'Autre' }], acronym: "OTHER") }
    let(:other_zone_1) { create(:zone, labels: [{ designated_on: '1981-05-08', name: 'Zone 1' }], acronym: "Z1") }
    let(:other_zone_2) { create(:zone, labels: [{ designated_on: '1981-05-08', name: 'Zone 2' }], acronym: "Z2") }

    before do
      procedure.zones << [last_zone, other_zone_1, other_zone_2]
    end

    subject { get :zones, params: { id: procedure_id } }

    it 'assigns @zones with the correct order' do
      subject
      assigned_labels = assigns(:zones).map(&:label)
      expect(assigned_labels).to eq(['Zone 1', 'Zone 2', 'Autre'])
    end
  end

  describe 'POST #create' do
    context 'when all attributs are filled' do
      describe 'new procedure in database' do
        subject { post :create, params: { procedure: procedure_params } }

        it { expect { subject }.to change { Procedure.count }.by(1) }
      end

      context 'when procedure is correctly save' do
        before do
          post :create, params: { procedure: procedure_params }
        end

        subject { Procedure.last }

        it "create attributes" do
          expect(subject.libelle).to eq(libelle)
          expect(subject.description).to eq(description)
          expect(subject.organisation).to eq(organisation)
          expect(subject.administrateurs).to eq([admin])
          expect(subject.duree_conservation_dossiers_dans_ds).to eq(duree_conservation_dossiers_dans_ds)
          expect(subject.procedure_tags.pluck(:name)).to match_array(['Aao', 'Accompagnement'])
          expect(response).to redirect_to(champs_admin_procedure_path(Procedure.last))
          expect(flash[:notice]).to be_present

          # creates generic labels
          expect(subject.labels.size).to eq(5)
          expect(subject.labels.first.name).to eq('À examiner')
        end
      end

      describe "procedure is saved with custom retention period" do
        let(:duree_conservation_dossiers_dans_ds) { 17 }

        before do
          stub_const("Expired::DEFAULT_DOSSIER_RENTENTION_IN_MONTH", 18)
        end

        subject { post :create, params: { procedure: procedure_params } }

        it "must save retention period and max retention period" do
          expect { subject }.to change { Procedure.count }.by(1)

          last_procedure = Procedure.last
          expect(last_procedure.duree_conservation_dossiers_dans_ds).to eq(duree_conservation_dossiers_dans_ds)
          expect(last_procedure.max_duree_conservation_dossiers_dans_ds).to eq(Expired::DEFAULT_DOSSIER_RENTENTION_IN_MONTH)
        end
      end

      context 'when procedure is correctly saved' do
        let(:instructeur) { admin.instructeur }

        before do
          post :create, params: { procedure: procedure_params }
        end

        describe "admin can also instruct the procedure as a instructeur" do
          subject { Procedure.last }
          it { expect(subject.defaut_groupe_instructeur.instructeurs).to include(instructeur) }
        end
      end
    end

    context 'when many attributs are not valid' do
      let(:libelle) { '' }
      let(:description) { '' }
      subject { post :create, params: { procedure: procedure_params } }

      describe 'no new procedure in database' do
        it do
          expect { subject }.to change { Procedure.count }.by(0)
          expect(flash[:alert]).to be_present
        end

        describe 'no new module api carto in database' do
          it { expect { subject }.to change { ModuleAPICarto.count }.by(0) }
        end
      end
    end
  end

  describe 'PUT #update' do
    let!(:procedure) { create(:procedure, :with_type_de_champ, administrateur: admin, procedure_expires_when_termine_enabled: false) }

    context 'when administrateur is not connected' do
      before do
        sign_out(admin.user)
      end

      subject { put :update, params: { id: procedure.id } }

      it { is_expected.to redirect_to new_user_session_path }
    end

    context 'when administrateur is connected' do
      def update_procedure
        put :update, params: { id: procedure.id, procedure: procedure_params.merge(procedure_params_not_creatable).merge(procedure_expires_when_termine_enabled: true) }
        procedure.reload
      end

      context 'when all attributs are present' do
        let(:libelle) { 'Blable' }
        let(:description) { 'blabla' }
        let(:organisation) { 'plop' }
        let(:duree_conservation_dossiers_dans_ds) { 7 }
        let(:procedure_expires_when_termine_enabled) { true }

        before { update_procedure }

        describe 'procedure attributs in database' do
          subject { procedure }

          it "update attributes" do
            expect(subject.libelle).to eq(libelle)
            expect(subject.description).to eq(description)
            expect(subject.organisation).to eq(organisation)
            expect(subject.duree_conservation_dossiers_dans_ds).to eq(duree_conservation_dossiers_dans_ds)
            expect(subject.procedure_expires_when_termine_enabled).to eq(true)
            expect(subject.lien_site_web).to eq(lien_site_web)
            expect(subject.robots_indexable?).to eq(false)
          end
        end

        it do
          is_expected.to redirect_to(admin_procedure_path id: procedure.id)
          expect(flash[:notice]).to be_present
        end
      end

      context 'when many attributs are not valid' do
        before { update_procedure }
        let(:libelle) { '' }
        let(:description) { '' }

        describe 'flash message is present' do
          it { expect(flash[:alert]).to be_present }
        end
      end

      context 'when procedure is brouillon' do
        let(:procedure) { create(:procedure_with_dossiers, :with_path, :with_type_de_champ, administrateur: admin) }
        let!(:dossiers_count) { procedure.dossiers.count }

        describe 'dossiers are dropped' do
          subject { update_procedure }

          it {
            expect(dossiers_count).to eq(1)
            expect(subject.dossiers.count).to eq(0)
          }
        end
      end

      context 'when procedure is published' do
        let(:procedure) { create(:procedure, :with_type_de_champ, :published, administrateur: admin) }

        subject { update_procedure }

        it 'only some properties can be updated' do
          expect(subject.libelle).to eq procedure_params[:libelle]
          expect(subject.description).to eq procedure_params[:description]
          expect(subject.organisation).to eq procedure_params[:organisation]
          expect(subject.for_individual).not_to eq procedure_params[:for_individual]
        end
      end
    end
  end

  describe 'GET #clone_settings' do
    render_views
    let(:procedure) { create(:procedure, :with_service, administrateur: admin, instructeurs: [admin.instructeur], api_entreprise_token: nil) }
    let(:params) { { procedure_id: procedure.id } }

    subject do
      get :clone_settings, params: params
    end

    context 'when admin is the owner of the procedure' do
      it 'displays all relevant options' do
        is_expected.to have_http_status(:success)
        expect(response.body).to include "Service"
        expect(response.body).to include "Administrateurs"
        expect(response.body).to include "Instructeurs"
        expect(response.body).not_to include "Jeton API entreprise"
      end
    end

    context 'when admin is not the owner of the procedure' do
      before do
        sign_out(admin.user)
        sign_in(administrateur_2.user)
        subject
      end

      it 'hides some options' do
        is_expected.to have_http_status(:success)
        expect(response.body).not_to include "Service"
        expect(response.body).not_to include "Administrateurs"
        expect(response.body).not_to include "Instructeurs"
      end
    end

    context 'when admin is not the owner of the procedure, and procedure is hidden as template' do
      before do
        sign_out(admin.user)
        sign_in(administrateur_3.user)
        procedure.update(hidden_at_as_template: Time.zone.now)
        subject
      end

      it 'redirects to procedures index' do
        is_expected.to redirect_to(admin_procedures_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'POST #clone' do
    let(:procedure) do
      create(
        :procedure,
        :with_type_de_champ,
        :with_type_de_champ_private,
        :with_notice,
        :with_deliberation,
        :with_logo,
        :with_labels,
        :with_zone,
        :with_service,
        :routee,
        :with_dossier_submitted_message,
        :with_labels,
        :sva,
        monavis_embed:,
        administrateurs: [admin, administrateur_2],
        instructeurs: [admin.instructeur, instructeur_2],
        attestation_acceptation_template: build(:attestation_template),
        attestation_refus_template: build(:attestation_template, kind: 'refus'),
        accuse_lecture: true,
        api_entreprise_token:,
        initiated_mail:,
        received_mail:,
        closed_mail:,
        refused_mail:,
        without_continuation_mail:,
        re_instructed_mail:,
        experts_require_administrateur_invitation:,
        instructeurs_self_management_enabled:
      )
    end

    let(:monavis_embed) { '<a href="https://monavis.numerique.gouv.fr/Demarches/123456?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d4"><img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-bleu.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" /></a>' }
    let(:ineligibilite_message) { 'Votre demande est inéligible' }
    let(:ineligibilite_enabled) { true }
    let(:ineligibilite_rules) { ds_eq(constant(true), constant(true)) }
    let(:api_entreprise_token) { JWT.encode({ exp: 2.days.ago.to_i }, nil, "none") }
    let(:initiated_mail) { build(:initiated_mail) }
    let(:received_mail) { build(:received_mail) }
    let(:closed_mail) { build(:closed_mail) }
    let(:refused_mail) { build(:refused_mail) }
    let(:without_continuation_mail) { build(:without_continuation_mail) }
    let(:re_instructed_mail) { build(:re_instructed_mail) }
    let(:experts_require_administrateur_invitation) { true }
    let(:expert) { create(:expert) }
    let!(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: procedure) }
    let(:instructeurs_self_management_enabled) { true }

    let(:params) do
      {
        procedure_id: procedure.id,
        procedure: {
          libelle: procedure.libelle,
          clone_options: {
            instructeurs: '0',
          },
        },
      }
    end
    subject { post :clone, params: params }

    before do
      procedure.groupe_instructeurs.each { |gi| gi.update!(contact_information: create(:contact_information)) }
      procedure.active_revision.update(ineligibilite_rules:, ineligibilite_message:, ineligibilite_enabled:)

      procedure.defaut_groupe_instructeur.signature.attach(
        io: StringIO.new("signature"),
        filename: "signature.png",
        content_type: "image/png",
        metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
      )

      response = Typhoeus::Response.new(code: 200, body: 'Hello world')
      Typhoeus.stub(/active_storage\/disk/).and_return(response)
    end

    it { expect { subject }.to change(Procedure, :count).by(1) }

    context 'when admin is the owner of the procedure' do
      before { subject }

      it 'creates a new procedure and redirect to it' do
        expect(response).to redirect_to admin_procedure_path(id: Procedure.last.id)
        expect(Procedure.last.cloned_from_library).to be_falsey
        expect(procedure.labels.first.procedure_id).to eq(procedure.id)
        expect(flash[:notice]).to have_content 'Démarche clonée. Pensez à vérifier les paramètres avant publication.'
      end

      context 'when the procedure is cloned from the library' do
        let(:params) do
          {
            procedure_id: procedure.id,
            from_new_from_existing: true,
            procedure: {
              libelle: procedure.libelle,
              clone_options: {
                instructeurs: '0',
              },
            },
          }
        end

        it { expect(Procedure.last.cloned_from_library).to be(true) }
      end

      context 'when the admin checks all options' do
        let(:params) do
          {
            procedure_id: procedure.id,
            procedure: {
              libelle: 'Démarche avec un nouveau nom',
              clone_options: {
                administrateurs: '1',
                instructeurs: '1',
                champs: '1',
                annotations: '1',
                attestation_acceptation_template: '1',
                attestation_refus_template: '1',
                zones: '1',
                service: '1',
                monavis_embed: '1',
                dossier_submitted_message: '1',
                accuse_lecture: '1',
                api_entreprise_token: '1',
                sva_svr: '1',
                mail_templates: '1',
                ineligibilite: '1',
                avis: '1',
                labels: '1',
              },
            },
          }
        end

        it 'clones everything', :slow do
          expect(Procedure.last.notice.attached?).to be_truthy
          expect(Procedure.last.deliberation.attached?).to be_truthy
          expect(Procedure.last.logo.attached?).to be_truthy
          expect(Procedure.last.administrateurs).to include(administrateur_2)
          expect(Procedure.last.defaut_groupe_instructeur.instructeurs).to match_array([admin.instructeur, instructeur_2])
          expect(Procedure.last.instructeurs_self_management_enabled).to be_truthy
          expect(Procedure.last.draft_revision.types_de_champ_public.count).to eq 1
          expect(Procedure.last.draft_revision.types_de_champ_private.count).to eq 1
          expect(Procedure.last.attestation_acceptation_template).not_to be_nil
          expect(Procedure.last.attestation_refus_template).not_to be_nil
          expect(Procedure.last.zones).not_to be_blank
          expect(Procedure.last.service).not_to be_nil
          expect(Procedure.last.monavis_embed).not_to be_nil
          expect(Procedure.last.draft_revision.dossier_submitted_message).not_to be_nil
          expect(Procedure.last.accuse_lecture).to be_truthy
          expect(Procedure.last[:api_entreprise_token]).not_to be_nil
          expect(Procedure.last.sva_svr_configuration.decision).to eq('sva')
          expect(Procedure.last.initiated_mail).not_to be_nil
          expect(Procedure.last.received_mail).not_to be_nil
          expect(Procedure.last.closed_mail).not_to be_nil
          expect(Procedure.last.refused_mail).not_to be_nil
          expect(Procedure.last.without_continuation_mail).not_to be_nil
          expect(Procedure.last.re_instructed_mail).not_to be_nil
          expect(Procedure.last.draft_revision.ineligibilite_rules).not_to be_nil
          expect(Procedure.last.draft_revision.ineligibilite_enabled).to be_truthy
          expect(Procedure.last.draft_revision.ineligibilite_message).to eq('Votre demande est inéligible')
          expect(Procedure.last.experts_require_administrateur_invitation).to be_truthy
          expect(Procedure.last.experts).not_to be_blank
          expect(Procedure.last.labels).not_to be_blank
          expect(Procedure.last.labels.first.procedure_id).to eq(Procedure.last.id)
          expect(Procedure.last.libelle).to eq 'Démarche avec un nouveau nom'
          expect(Procedure.last.defaut_groupe_instructeur.signature.attached?).to be_truthy
        end
      end

      context 'when the admin unchecks all options' do
        let(:params) do
          {
            procedure_id: procedure.id,
            procedure: {
              libelle: procedure.libelle,
              clone_options: {
                administrateurs: '0',
                instructeurs: '0',
                champs: '0',
                annotations: '0',
                attestation_acceptation_template: '0',
                attestation_refus_template: '0',
                zones: '0',
                service: '0',
                monavis_embed: '0',
                dossier_submitted_message: '0',
                accuse_lecture: '0',
                api_entreprise_token: '0',
                sva_svr: '0',
                mail_templates: '0',
                ineligibilite: '0',
                avis: '0',
                labels: '0',
              },
            },
          }
        end

        it 'clones only mandatory params' do
          expect(Procedure.last.notice.attached?).to be_truthy
          expect(Procedure.last.deliberation.attached?).to be_truthy
          expect(Procedure.last.logo.attached?).to be_truthy
          expect(Procedure.last.administrateurs).not_to include(administrateur_2)
          expect(Procedure.last.administrateurs).to include(admin)
          expect(Procedure.last.defaut_groupe_instructeur.instructeurs).to eq([admin.instructeur])
          expect(Procedure.last.groupe_instructeurs.count).to eq(1)
          expect(Procedure.last.routing_enabled).to be_falsey
          expect(Procedure.last.defaut_groupe_instructeur.contact_information).to be_nil
          expect(Procedure.last.instructeurs_self_management_enabled).to be_falsey
          expect(Procedure.last.draft_revision.types_de_champ_public.count).to eq 0
          expect(Procedure.last.draft_revision.types_de_champ_private.count).to eq 0
          expect(Procedure.last.attestation_acceptation_template).to be_nil
          expect(Procedure.last.attestation_refus_template).to be_nil
          expect(Procedure.last.zones).to be_blank
          expect(Procedure.last.service).to be_nil
          expect(Procedure.last.monavis_embed).to be_nil
          expect(Procedure.last.draft_revision.dossier_submitted_message).to be_nil
          expect(Procedure.last.accuse_lecture).to be_falsey
          expect(Procedure.last[:api_entreprise_token]).to be_nil
          expect(Procedure.last.sva_svr_configuration.decision).to eq('disabled')
          expect(Procedure.last.initiated_mail).to be_nil
          expect(Procedure.last.received_mail).to be_nil
          expect(Procedure.last.closed_mail).to be_nil
          expect(Procedure.last.refused_mail).to be_nil
          expect(Procedure.last.without_continuation_mail).to be_nil
          expect(Procedure.last.re_instructed_mail).to be_nil
          expect(Procedure.last.draft_revision.ineligibilite_rules).to be_nil
          expect(Procedure.last.draft_revision.ineligibilite_enabled).to be_falsey
          expect(Procedure.last.draft_revision.ineligibilite_message).to be_nil
          expect(Procedure.last.experts_require_administrateur_invitation).to be_falsey
          expect(Procedure.last.experts).to be_blank
          expect(Procedure.last.labels).to be_blank
          expect(Procedure.last.defaut_groupe_instructeur.signature.attached?).to be_falsey
        end
      end
    end

    context 'when admin is not the owner of the procedure' do
      before do
        sign_out(admin.user)
        sign_in(administrateur_3.user)
        subject
      end

      it 'creates a new procedure and redirect to it' do
        expect(response).to redirect_to admin_procedure_path(id: Procedure.last.id)
        expect(flash[:notice]).to have_content 'Démarche clonée. Pensez à vérifier les paramètres avant publication.'
      end
    end

    context 'when admin is not the owner of the procedure, and procedure is hidden as template' do
      before do
        sign_out(admin.user)
        sign_in(administrateur_3.user)
        procedure.update(hidden_at_as_template: Time.zone.now)
        subject
      end

      it 'redirects to procedures index' do
        is_expected.to redirect_to(admin_procedures_path)
        expect(flash[:alert]).to be_present
      end
    end

    context 'when procedure has invalid fields' do
      let(:admin_2) { administrateurs(:default_admin) }
      let(:path) { 'spec/fixtures/files/invalid_file_format.json' }

      before do
        sign_out(admin.user)
        sign_in(admin_2.user)

        procedure.notice.attach(io: File.open(path),
        filename: "invalid_file_format.json",
        content_type: "application/json",
        metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE })

        procedure.deliberation.attach(io: File.open(path),
        filename: "invalid_file_format.json",
        content_type: "application/json",
        metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE })

        procedure.created_at = Date.new(2020, 2, 27)
        procedure.save!

        subject { put :clone, params: { procedure_id: procedure.id } }
      end

      it 'empty invalid fields and allow procedure to be cloned' do
        expect(response).to redirect_to admin_procedure_path(id: Procedure.last.id)
        expect(Procedure.last.notice.attached?).to be_falsey
        expect(Procedure.last.deliberation.attached?).to be_falsey
        expect(flash[:notice]).to have_content 'Démarche clonée. Pensez à vérifier les paramètres avant publication.'
      end
    end
  end

  describe 'PUT #archive' do
    let(:procedure) { create(:procedure, :published, administrateur: admin, lien_site_web: lien_site_web) }

    context 'when the admin is an owner of the procedure without procedure replacement' do
      before do
        put :archive, params: { procedure_id: procedure.id, procedure: { closing_reason: 'other' } }
        procedure.reload
      end

      it 'archives the procedure' do
        expect(procedure.close?).to be_truthy
        expect(response).to redirect_to admin_procedure_path(procedure.id)
        expect(flash[:notice]).to have_content 'Démarche close'
      end

      it 'does not have any replacement procedure' do
        expect(procedure.replaced_by_procedure).to be_nil
        expect(procedure.closing_reason).to eq('other')
      end

      context 'the admin can notify users if there are file in brouillon or en_cours' do
        let!(:procedure) { create(:procedure_with_dossiers, :published, dossiers_count: 2, administrateur: admin, lien_site_web: lien_site_web) }
        it 'archives the procedure and redirects to page to notify users' do
          expect(procedure.close?).to be_truthy
          expect(response).to redirect_to :admin_procedure_closing_notification
        end
      end
    end

    context 'when the admin is an owner of the procedure with procedure replacement in DS' do
      let(:procedure) { create(:procedure_with_dossiers, :published, administrateur: admin, lien_site_web: lien_site_web) }
      let(:new_procedure) { create(:procedure, :published, administrateur: admin, lien_site_web: lien_site_web) }
      before do
        put :archive, params: { procedure_id: procedure.id, procedure: { closing_reason: 'internal_procedure', replaced_by_procedure_id: new_procedure.id } }
        procedure.reload
      end

      it 'archives the procedure' do
        expect(procedure.close?).to be_truthy
        expect(response).to redirect_to admin_procedure_closing_notification_path
      end

      it 'does have a replacement procedure' do
        expect(procedure.replaced_by_procedure).to eq(new_procedure)
        expect(procedure.closing_reason).to eq('internal_procedure')
      end
    end

    context 'when the admin is an owner of the procedure with procedure replacement outside DS' do
      let(:new_procedure) { create(:procedure, :published, administrateur: admin, lien_site_web: lien_site_web) }
      before do
        put :archive, params: { procedure_id: procedure.id, procedure: { closing_reason: 'other', closing_details: "Sorry it's closed" } }
        procedure.reload
      end

      it 'archives the procedure' do
        expect(procedure.close?).to be_truthy
        expect(response).to redirect_to admin_procedure_path(procedure.id)
        expect(flash[:notice]).to have_content 'Démarche close'
      end
    end

    context 'when the admin is not an owner of the procedure' do
      let(:admin_2) { create(:administrateur) }

      before do
        sign_out(admin.user)
        sign_in(admin_2.user)

        put :archive, params: { procedure_id: procedure.id, procedure: { closing_reason: 'other' } }
        procedure.reload
      end

      it 'displays an error message' do
        expect(response).to redirect_to :admin_procedures
        expect(flash[:alert]).to have_content 'Démarche inexistante'
      end
    end

    context 'when the admin is not an owner of the new procedure in DS' do
      let(:admin_2) { create(:administrateur) }
      let(:other_admin_procedure) { create(:procedure, :with_all_champs, administrateurs: [admin_2]) }

      before do
        put :archive, params: { procedure_id: procedure.id, procedure: { closing_reason: 'internal_procedure', replaced_by_procedure_id: other_admin_procedure.id } }
        procedure.reload
      end

      it 'does not close the procedure' do
        expect(response).to redirect_to admin_procedure_close_path
        expect(flash[:alert]).to have_content 'Le champ « Nouvelle démarche » doit être rempli'
        expect(procedure.close?).to be_falsey
        expect(procedure.replaced_by_procedure).to eq(nil)
      end
    end
  end

  describe 'POST #notify_after_closing' do
    let(:procedure_closed) { create(:procedure_with_dossiers, :closed, administrateurs: [admin]) }
    let(:user_ids) { [procedure_closed.dossiers.first.user.id] }
    let(:email_content) { "La démarche a fermé" }

    subject do
      post :notify_after_closing, params: { procedure_id: procedure_closed.id, procedure: { closing_notification_brouillon: true }, email_content_brouillon: email_content }
    end

    before do
      sign_in(admin.user)
    end

    it 'redirects to admin procedures' do
      expect { subject }.to have_enqueued_job(SendClosingNotificationJob).with(user_ids, email_content, procedure_closed)
      expect(flash.notice).to eq("Les emails sont en cours d’envoi")
      expect(response).to redirect_to :admin_procedures
    end
  end

  describe 'DELETE #destroy' do
    let(:procedure_draft)     { create(:procedure, administrateurs: [admin]) }
    let(:procedure_published) { create(:procedure, :published, administrateurs: [admin]) }
    let(:procedure_closed)    { create(:procedure, :closed, administrateurs: [admin]) }
    let(:procedure) { dossier.procedure }

    subject { delete :destroy, params: { id: procedure } }

    context 'when the procedure is a brouillon' do
      let(:dossier) { create(:dossier, :en_instruction, procedure: procedure_draft) }

      before { subject }

      it 'deletes associated dossiers' do
        expect(procedure.dossiers.count).to eq(0)
      end

      it 'redirects to the procedure drafts page' do
        expect(response).to redirect_to admin_procedures_draft_path
        expect(flash[:notice]).to be_present
      end
    end

    context 'when procedure is published' do
      let(:dossier) { create(:dossier, :en_instruction, procedure: procedure_published) }

      before { subject }

      it { expect(response.status).to eq 403 }

      context 'when dossier is en_construction' do
        let(:dossier) { create(:dossier, :en_construction, procedure: procedure_published) }

        it do
          expect(procedure.reload.close?).to be_truthy
          expect(procedure.discarded?).to be_truthy
          expect(dossier.reload.visible_by_administration?).to be_falsy
        end
      end

      context 'when dossier is accepte' do
        let(:dossier) { create(:dossier, :accepte, procedure: procedure_published) }

        it do
          expect(procedure.reload.close?).to be_truthy
          expect(procedure.discarded?).to be_truthy
          expect(dossier.reload.hidden_by_administration?).to be_truthy
        end
      end
    end

    context 'when procedure is closed' do
      let(:dossier) { create(:dossier, :en_instruction, procedure: procedure_closed) }

      before { subject }

      it { expect(response.status).to eq 403 }

      context 'when dossier is en_construction' do
        let(:dossier) { create(:dossier, :en_construction, procedure: procedure_published) }

        it do
          expect(procedure.reload.discarded?).to be_truthy
          expect(dossier.reload.visible_by_administration?).to be_falsy
        end
      end

      context 'when dossier is accepte' do
        let(:dossier) { create(:dossier, :accepte, procedure: procedure_published) }

        it do
          expect(procedure.reload.discarded?).to be_truthy
          expect(dossier.reload.hidden_by_administration?).to be_truthy
        end
      end
    end

    context "when administrateur does not own the procedure" do
      let(:dossier) { create(:dossier, procedure: create(:procedure, :new_administrateur)) }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe 'PATCH #monavis' do
    let!(:procedure) { create(:procedure, administrateur: admin) }
    let(:procedure_params) {
      {
        monavis_embed: monavis_embed,
      }
    }

    context 'when administrateur is not connected' do
      before do
        sign_out(admin.user)
      end

      subject { patch :update_monavis, params: { id: procedure.id } }

      it { is_expected.to redirect_to new_user_session_path }
    end

    context 'when administrateur is connected' do
      def update_monavis
        patch :update_monavis, params: { id: procedure.id, procedure: procedure_params }
        procedure.reload
      end
      let(:monavis_embed) {
        <<-MSG
        <a href="https://monavis.numerique.gouv.fr/Demarches/123?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d475e4045666057f">
          <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-blanc.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
      }

      context 'when all attributes are present' do
        render_views

        subject { update_monavis }

        context 'when the embed code is valid' do
          it 'the monavis field is updated' do
            subject

            expect(procedure.monavis_embed).to eq(monavis_embed)
            expect(flash[:notice]).to be_present
            expect(response).to redirect_to(admin_procedure_path(procedure.id))
          end
        end

        context 'when the embed code is not valid' do
          let(:monavis_embed) { 'invalid embed code' }

          it 'the monavis field is not updated' do
            expect(subject.monavis_embed).to eq(nil)
            expect(flash[:alert]).to be_present
            expect(response.body).to include "MonAvis"
          end
        end
      end

      context 'when procedure is published' do
        let(:procedure) { create(:procedure, :published, administrateur: admin) }

        subject { update_monavis }

        describe 'the monavis field is not updated' do
          it { expect(subject.monavis_embed).to eq monavis_embed }
        end
      end
    end
  end

  describe 'GET #check_path' do
    render_views

    let(:procedure) { create(:procedure, :published, administrateur: admin) }

    subject(:perform_request) { get :check_path, params: { procedure_id: procedure.id, procedure: { path: } }, format: :turbo_stream }

    context 'when path is not used' do
      let(:path) { SecureRandom.uuid }

      it do
        perform_request
        is_expected.to have_http_status(:success)
        expect(response.body).to include('<turbo-stream action="update" target="check_path"><template></template></turbo-stream>')
      end
    end

    context 'when path is used' do
      context "by same admin" do
        let(:procedure_path) { build(:procedure_path, path: "plop") }
        let!(:procedure2) { create(:procedure, :published, administrateur: admin, procedure_paths: [procedure_path]) }

        let(:path) { "plop" }

        it do
          perform_request
          is_expected.to have_http_status(:success)
          expect(response.body).to include('<turbo-stream action="update" target="check_path">')
          expect(response.body).to include('Cette url est identique à celle d’une autre de vos démarches publiées.')
        end
      end

      context "by another admin" do
        let(:procedure_path) { build(:procedure_path, path: "plip") }
        let!(:procedure3) { create(:procedure, :published, administrateur: create(:administrateur), procedure_paths: [procedure_path]) }

        let(:path) { "plip" }

        it do
          perform_request
          is_expected.to have_http_status(:success)
          expect(response.body).to include('<turbo-stream action="update" target="check_path">')
          expect(response.body).to include('Cette url est identique à celle d’une autre démarche, vous devez la modifier afin de pouvoir publier votre démarche.')
        end
      end
    end
  end

  describe 'PATCH #update_path' do
    let(:procedure) { create(:procedure, administrateur: admin) }

    subject(:perform_request) { patch :update_path, params: { procedure_id: procedure.id, path: path } }

    context 'when path is not used' do
      let(:path) { "ma-demarche" }

      it 'updates the procedure path' do
        perform_request
        expect(response).to redirect_to(admin_procedure_path(procedure))
        expect(flash[:notice]).to eq("L'URL de la démarche a bien été mise à jour")
        expect(procedure.reload.path).to eq(path)
      end
    end

    context 'when path is used' do
      context "by same admin" do
        let(:procedure_path) { build(:procedure_path, path: "plop") }
        let!(:procedure2) { create(:procedure, :published, administrateur: admin, procedure_paths: [procedure_path]) }
        let(:path) { "plop" }

        it 'updates the procedure path' do
          perform_request
          expect(response).to redirect_to(admin_procedure_path(procedure))
          expect(flash[:notice]).to eq("L'URL de la démarche a bien été mise à jour")
          expect(procedure.reload.path).to eq(path)
        end
      end

      context "by another admin" do
        let(:procedure_path) { build(:procedure_path, path: "plip") }
        let!(:procedure3) { create(:procedure, :published, administrateur: create(:administrateur), procedure_paths: [procedure_path]) }
        let(:path) { "plip" }

        it 'fails to update the path' do
          perform_request
          expect(response).to redirect_to(admin_procedure_path_path(procedure))
          expect(flash[:alert]).to eq("Cette URL de démarche n’est pas disponible")
          expect(procedure.reload.path).not_to eq(path)
        end
      end
    end

    context 'when path is invalid' do
      let(:path) { 'Invalid Path!' }

      it 'fails to update the path' do
        perform_request
        expect(response).to render_template(:path)
        expect(flash[:alert]).to be_present
        expect(procedure.reload.path).not_to eq(path)
      end
    end
  end

  describe 'GET #publication' do
    subject(:perform_request) { get :publication, params: { procedure_id: procedure.id } }

    context 'when procedure is closed' do
      let(:procedure) { create(:procedure, :closed, administrateur: admin) }

      it 'assigns procedure' do
        perform_request
        expect(response).to have_http_status(:ok)
      end

      context 'with auto_archive on past' do
        before do
          procedure.auto_archive_on = Date.today - 1.week
          procedure.save(validate: false)
        end

        it 'suggest to update autoarchive' do
          perform_request
          expect(response).to redirect_to(admin_procedure_path(procedure.id))
          expect(flash.alert).to include('La date limite de dépôt des dossiers doit être postérieure à la date du jour pour réactiver la procédure.')
        end
      end
    end
  end

  describe 'PUT #publish' do
    let(:procedure) { create(:procedure, administrateur: admin, lien_site_web: lien_site_web) }
    let(:procedure2) { create(:procedure, :published, administrateur: admin, lien_site_web: lien_site_web) }
    let(:procedure3) { create(:procedure, :published, :new_administrateur, lien_site_web: lien_site_web) }
    let(:lien_site_web) { 'http://some.administration/' }
    let(:robots_indexable) { "0" }
    let(:tdc_attributes) { { type_champ: :number, libelle: 'libelle 1' } }

    subject(:perform_request) { put :publish, params: { procedure_id: procedure.id, procedure: { path:, lien_site_web:, robots_indexable: } } }

    context 'when admin is the owner of the procedure' do
      context 'procedure path does not exist' do
        let(:path) { 'new_path' }
        let(:lien_site_web) { 'http://mon-site.gouv.fr' }

        before do
          perform_request
          procedure.reload
        end

        it 'publish the given procedure and redirects to the confirmation page' do
          expect(procedure.publiee?).to be_truthy
          expect(procedure.path).to eq(path)
          expect(procedure.lien_site_web).to eq(lien_site_web)
          expect(procedure.robots_indexable?).to be(false)

          expect(response).to redirect_to(admin_procedure_confirmation_path(procedure))
        end
      end

      context 'procedure path exists and is owned by current administrator' do
        before do
          perform_request
          procedure.reload
          procedure2.reload
        end

        let(:path) { procedure2.path }
        let(:lien_site_web) { 'http://mon-site.gouv.fr' }
        let(:robots_indexable) { '1' }

        it 'publishes the procedure, unpublishes the old one and redirects to confirmation page' do
          expect(procedure.publiee?).to be_truthy
          expect(procedure.path).to eq(path)
          expect(procedure.lien_site_web).to eq(lien_site_web)
          expect(procedure.robots_indexable?).to be(true)

          expect(procedure2.depubliee?).to be_truthy

          expect(response).to redirect_to(admin_procedure_confirmation_path(procedure))
        end
      end

      context 'procedure was closed and is re opened' do
        before do
          procedure.publish!(procedure.administrateurs.first)
          procedure.update!(closing_reason: 'internal_procedure', replaced_by_procedure_id: procedure2.id)
          procedure.close!
          procedure.update!(closing_notification_brouillon: true, closing_notification_en_cours: true)
          procedure.draft_revision.add_type_de_champ(tdc_attributes)
          perform_request
          procedure.reload
          procedure2.reload
        end

        it 'publish the given procedure, reset closing params and publish revision if procedure changed' do
          expect(procedure.publiee?).to be_truthy
          expect(procedure.path).to eq(path)
          expect(procedure.closing_reason).to be_nil
          expect(procedure.replaced_by_procedure_id).to be_nil
          expect(procedure.closing_notification_brouillon).to be_falsy
          expect(procedure.closing_notification_en_cours).to be_falsy
          expect(procedure.published_revision.types_de_champ_public.first.libelle).to eq('libelle 1')
        end
      end

      context 'procedure path exists and is not owned by current administrator' do
        let(:path) { procedure3.path }
        let(:lien_site_web) { 'http://mon-site.gouv.fr' }

        it {
          expect { perform_request }.not_to change { procedure.reload.updated_at }
          expect(response).to redirect_to(admin_procedure_publication_path(procedure.id))
          expect(flash[:alert]).to have_content "« Lien public » est déjà utilisé"
        }
      end

      context 'procedure path is invalid' do
        let(:lien_site_web) { 'http://mon-site.gouv.fr' }
        let(:path) { 'Invalid Procedure Path' }

        it {
          expect { perform_request }.not_to change { procedure.reload.updated_at }
          expect(flash[:alert]).to have_content "Le champ « Lien public » n’est pas valide"
        }
      end

      context 'procedure revision is invalid' do
        let(:path) { 'new_path' }
        let(:procedure) do
          create(:procedure,
                 administrateur: admin,
                 lien_site_web: lien_site_web,
                 types_de_champ_public: [{ type: :repetition, children: [] }])
        end

        it {
          expect { perform_request }.not_to change { procedure.reload.updated_at }
          expect(flash[:alert]).to have_content "doit comporter au moins un champ"
        }
      end
    end

    context 'when admin is not the owner of the procedure' do
      let(:admin_2) { create(:administrateur) }
      before do
        sign_out(admin.user)
        sign_in(admin_2.user)

        put :publish, params: { procedure_id: procedure.id, path: 'fake_path' }
        procedure.reload
      end

      it 'fails' do
        expect(response).to have_http_status(404)
      end
    end

    context 'when the admin does not provide a lien_site_web' do
      context 'procedure path is valid but lien_site_web is missing' do
        let(:path) { 'new_path2' }
        let(:lien_site_web) { nil }
        it {
          expect { perform_request }.not_to change { procedure.reload.updated_at }
          expect(flash[:alert]).to have_content "doit être rempli"
        }
      end
    end
  end

  describe 'POST #transfer' do
    let!(:procedure) { create :procedure, :with_service, administrateur: admin }

    before do
      post :transfer, params: { email_admin: email_admin, procedure_id: procedure.id }
      procedure.reload
    end

    subject do
      post :transfer, params: { email_admin: email_admin, procedure_id: procedure.id }
    end

    context 'when admin is unknow' do
      let(:email_admin) { 'plop' }

      it do
        expect(response).to redirect_to(admin_procedure_transfert_path(procedure.id))
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to eq("Envoi vers #{email_admin} impossible : cet administrateur n’existe pas")
      end
    end

    context 'when admin is known' do
      let!(:new_admin) { create :administrateur, email: 'new_admin@admin.com' }

      context "and its email address is correct" do
        let(:email_admin) { 'new_admin@admin.com' }

        it do
          expect { subject }.to change(new_admin.procedures, :count).by(1)
          expect(subject).to be_redirection
        end

        it "should create a new service" do
          subject
          expect(new_admin.procedures.last.service_id).not_to eq(procedure.service_id)
        end
      end

      context 'when admin is know but its email was not downcased' do
        let(:email_admin) { "NEW_admin@adMIN.com" }

        it do
          expect { subject }.to change(Procedure, :count).by(1)
          expect(subject).to be_redirection
        end
      end

      describe "correctly assigns the new admin" do
        let(:email_admin) { 'new_admin@admin.com' }

        before do
          subject
        end

        it { expect(Procedure.last.administrateurs).to eq [new_admin] }
      end
    end
  end

  describe 'PUT #allow_expert_review' do
    let!(:procedure) { create :procedure, :with_service, administrateur: admin }

    context 'when admin refuse to invite experts on this procedure' do
      before do
        procedure.update!(allow_expert_review: false)
        procedure.reload
      end

      it { expect(procedure.allow_expert_review).to be_falsy }
    end

    context 'when admin accept to invite experts on this procedure (true by default)' do
      it { expect(procedure.allow_expert_review).to be_truthy }
    end
  end

  describe 'PUT #allow_expert_messaging' do
    let!(:procedure) { create :procedure, :with_service, administrateur: admin }

    context 'when admin refuse to let experts discuss with users on this procedure' do
      before do
        procedure.update!(allow_expert_messaging: false)
        procedure.reload
      end

      it { expect(procedure.allow_expert_messaging).to be_falsy }
    end

    context 'when admin accept to let experts discuss with users (true by default)' do
      it { expect(procedure.allow_expert_messaging).to be_truthy }
    end
  end

  describe 'PUT #restore' do
    let(:procedure) { create :procedure_with_dossiers, :with_service, :published, administrateur: admin }

    before do
      procedure.discard_and_keep_track!(admin)
    end

    context 'when the admin wants to restore a procedure' do
      before do
        put :restore, params: { id: procedure.id }
        procedure.reload
      end

      it do
        expect(procedure.discarded?).to be_falsy
        expect(procedure.dossiers.first.hidden_by_administration_at).to be_nil
      end
    end
  end

  describe '#update_rdv' do
    let(:admin) { create(:administrateur) }
    let(:procedure) { create(:procedure, administrateurs: [admin]) }

    before { sign_in(admin.user) }

    context 'when enabling rdv' do
      before do
        patch :update_rdv, params: {
          id: procedure.id,
          procedure: { rdv_enabled: true },
        }
      end

      it 'updates the procedure' do
        expect(procedure.reload.rdv_enabled).to be true
      end

      it 'sets a success message' do
        expect(flash.notice).to eq("La prise de rendez-vous est activée")
      end

      it 'redirects to rdv admin procedure path' do
        expect(response).to redirect_to(rdv_admin_procedure_path(procedure))
      end
    end

    context 'when disabling rdv' do
      let(:procedure) { create(:procedure, rdv_enabled: true, administrateurs: [admin]) }

      before do
        patch :update_rdv, params: {
          id: procedure.id,
          procedure: { rdv_enabled: false },
        }
      end

      it 'updates the procedure' do
        expect(procedure.reload.rdv_enabled).to be false
      end

      it 'sets a success message' do
        expect(flash.notice).to eq("La prise de rendez-vous est désactivée")
      end

      it 'redirects to rdv admin procedure path' do
        expect(response).to redirect_to(rdv_admin_procedure_path(procedure))
      end
    end
  end

  describe '#update_pro_connect_restricted' do
    let(:admin) { create(:administrateur) }
    let(:procedure) { create(:procedure, administrateurs: [admin]) }

    before { sign_in(admin.user) }

    subject do
      patch :update_pro_connect_restricted, params: {
        id: procedure.id,
        procedure: { pro_connect_restriction: restriction_level },
      }
    end

    context 'when admin is connected to pro_connect' do
      before do
        cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = { value: { user_id: admin.user.id }.to_json }
        subject
      end

      context 'when setting to :none' do
        let(:restriction_level) { 'none' }

        it do
          expect(procedure.reload.pro_connect_restriction_none?).to be true
          expect(flash.notice).to eq("La démarche n’est plus restreinte à ProConnect")
          expect(response).to redirect_to(pro_connect_restricted_admin_procedure_path(procedure))
        end
      end

      context 'when setting to :instructeurs' do
        let(:restriction_level) { 'instructeurs' }

        it do
          expect(procedure.reload.pro_connect_restriction_instructeurs?).to be true
          expect(flash.notice).to eq("La démarche est restreinte à ProConnect pour les administrateurs et instructeurs")
          expect(response).to redirect_to(pro_connect_restricted_admin_procedure_path(procedure))
        end
      end

      context 'when setting to :all' do
        let(:procedure) { create(:procedure, opendata: true, robots_indexable: true, administrateurs: [admin]) }
        let(:restriction_level) { 'all' }

        it do
          procedure.reload
          expect(procedure.pro_connect_restriction_all?).to be true
          expect(procedure.opendata).to be false
          expect(procedure.robots_indexable).to be false
          expect(flash.notice).to eq("La démarche est restreinte à ProConnect pour les administrateurs, instructeurs et dépositaires de dossiers")
          expect(response).to redirect_to(pro_connect_restricted_admin_procedure_path(procedure))
        end
      end
    end
  end

  describe '#select_procedure' do
    let(:admin) { create(:administrateur) }

    before do
      sign_in(admin.user)
    end

    context 'when procedure_id is present' do
      let(:procedure) { create(:procedure, administrateur: admin) }

      it 'redirects to the procedure path' do
        get :select_procedure, params: { procedure_id: procedure.id }

        expect(response).to redirect_to(admin_procedure_path(procedure.id))
      end
    end

    context 'when procedure_id is not present' do
      it 'redirects to procedures index' do
        get :select_procedure

        expect(response).to redirect_to(admin_procedures_path)
      end
    end

    context 'when procedure_id is empty string' do
      it 'redirects to procedures index' do
        get :select_procedure, params: { procedure_id: '' }

        expect(response).to redirect_to(admin_procedures_path)
      end
    end

    context 'when procedure_id is nil' do
      it 'redirects to procedures index' do
        get :select_procedure, params: { procedure_id: nil }

        expect(response).to redirect_to(admin_procedures_path)
      end
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: procedure.id } }

    context 'when ProConnect is required' do
      let(:procedure) { create(:procedure, pro_connect_restriction: :instructeurs, administrateur: admin) }
      it 'redirects to pro_connect_path and sets a flash message' do
        subject

        expect(response).to redirect_to(pro_connect_path)
        expect(flash[:alert]).to eq("Vous devez vous connecter par ProConnect pour accéder à cette démarche")
      end

      context "and the cookie is set" do
        before do
          cookies.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = { value: { user_id: admin.user.id }.to_json }
        end

        it "does not redirect to pro_connect_path" do
          subject

          expect(response).not_to redirect_to(pro_connect_path)
        end
      end
    end
  end
end
