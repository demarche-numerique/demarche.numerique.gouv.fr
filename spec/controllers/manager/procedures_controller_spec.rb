# frozen_string_literal: true

describe Manager::ProceduresController, type: :controller do
  let(:super_admin) { create :super_admin }
  let(:administrateur) { create(:administrateur, email: super_admin.email) }
  let(:autre_administrateur) { administrateurs.default }
  before { sign_in super_admin }

  describe '#whitelist' do
    let(:procedure) { create(:procedure) }

    before do
      post :whitelist, params: { id: procedure.id }
      procedure.reload
    end

    it { expect(procedure.whitelisted?).to be_truthy }
  end

  describe '#hide_as_template' do
    let(:procedure) { create(:procedure) }

    before do
      post :hide_as_template, params: { id: procedure.id }
      procedure.reload
    end

    it { expect(procedure.hidden_as_template?).to be_truthy }
  end

  describe '#unhide_as_template' do
    let(:procedure) { create(:procedure) }

    before do
      post :unhide_as_template, params: { id: procedure.id }
      procedure.reload
    end

    it { expect(procedure.hidden_as_template?).to be_falsey }
  end

  describe '#show' do
    render_views

    let(:procedure) { create(:procedure, :published, email_depose: build(:email_depose), public_type_de_champs: [{ type: :repetition, children: [{ type: :text, libelle: 'sub type de champ' }] }]) }

    before do
      get :show, params: { id: procedure.id }
    end

    it do
      expect(response.body).to include('sub type de champ')
      expect(response.body).to include('bonne réception de votre dossier')
      expect(response.body).to include('Hidden At As Template')
      expect(response.body).to include('Pro Connect Restriction')
      expect(response.body).to include('Pro Connect For Moral Procedure')
      expect(response.body).to include('Robots Indexable')
    end

    it 'links to the access grant confirmation page' do
      expect(response.body).to include(add_administrateur_and_instructeur_edit_manager_procedure_path(procedure))
    end

    context 'when sorting a has_many sub-table by an association column' do
      let(:procedure) { create(:procedure, administrateurs: [administrateur]) }

      before do
        get :show, params: { id: procedure.id, administrateurs: { order: 'procedures', direction: 'asc' } }
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end

  describe '#discard' do
    let(:dossier) { create(:dossier, :accepte) }
    let(:procedure) { dossier.procedure }

    before do
      post :discard, params: { id: procedure.id }
      procedure.reload
      dossier.reload
    end

    it do
      expect(procedure.discarded?).to be_truthy
      expect(dossier.hidden_by_administration?).to be_truthy
    end
  end

  describe '#restore' do
    let(:dossier) { create(:dossier, :accepte, :with_individual) }
    let(:procedure) { dossier.procedure }

    before do
      procedure.discard_and_keep_track!(super_admin)

      post :restore, params: { id: procedure.id }
      procedure.reload
    end

    it do
      expect(procedure.kept?).to be_truthy
      expect(dossier.hidden_by_administration?).to be_falsey
    end
  end

  describe '#index' do
    render_views

    context 'sort by dossiers' do
      let!(:procedure_1) { create(:procedure, libelle: 'Procédure 1', estimated_dossiers_count: 111) }
      let!(:procedure_2) { create(:procedure, libelle: 'Procédure 2', estimated_dossiers_count: 222) }

      before do
        get :index, params: { procedure: { direction: :asc, order: :estimated_dossiers_count } }
      end

      it "orders procedures by estimated_dossiers_count" do
        expect(response.body.index("Procédure 1"))
          .to be < response.body.index("Procédure 2")
      end
    end

    # Administrate construit une clause LIKE par attribut cherchable : un attribut
    # qui n'est plus une colonne fait planter n'importe quelle recherche.
    context 'search' do
      let(:suffix) { SecureRandom.hex(4) }
      let!(:procedure) { create(:procedure, administrateur:, libelle: "Demande de badge cachalot#{suffix}") }

      before { get :index, params: { search: "cachalot#{suffix}" } }

      # Une ligne du tableau Administrate porte un unique data-url vers la ressource.
      it { expect(response.body.scan(%r{data-url=/manager/procedures/#{procedure.id}\b}).size).to eq(1) }
    end
  end

  describe '#change_piece_justificative_template' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative }]) }
    let(:other_procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative }]) }
    let(:other_type_de_champ) { other_procedure.draft_revision.type_de_champs.first }
    let(:upload) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/RIB.pdf"),
        "application/pdf"
      )
    end

    subject(:cross_procedure_request) do
      post :change_piece_justificative_template, params: {
        id: procedure.id,
        type_de_champ: { id: other_type_de_champ.id, piece_justificative_template: upload },
      }
    rescue ActiveRecord::RecordNotFound
      nil
    end

    it "does not update the template of a type de champ from a different procedure" do
      expect { cross_procedure_request }
        .not_to change { other_type_de_champ.reload.piece_justificative_template.blob.id }
    end
  end

  describe '#delete_administrateur' do
    let(:procedure) { create(:procedure, :with_service, administrateurs: [administrateur, autre_administrateur]) }
    let(:administrateur) { create(:administrateur, email: super_admin.email) }

    subject(:delete_request) { put :delete_administrateur, params: { id: procedure.id } }

    it "removes the current administrateur from the procedure" do
      delete_request
      expect(procedure.administrateurs).to eq([autre_administrateur])
    end

    context 'when the current administrateur has been added as instructeur too' do
      let(:instructeur) { create(:instructeur) }
      let(:administrateur) { create(:administrateur, email: super_admin.email, instructeur: instructeur) }

      before do
        procedure.groupe_instructeurs.map do |groupe_instructeur|
          instructeur.assign_to.create!(groupe_instructeur: groupe_instructeur, manager: true)
        end
      end

      it "removes the instructeur from the procedure" do
        delete_request
        instructeur.groupe_instructeurs.each do |groupe_instructeur|
          expect(groupe_instructeur.instructeurs).not_to include(instructeur)
        end
      end
    end
  end

  describe '#add_administrateur_and_instructeur_edit' do
    render_views

    let(:procedure) { procedures.individual }

    it 'renders the confirmation page with the OTP input' do
      get :add_administrateur_and_instructeur_edit, params: { id: procedure.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(procedure.libelle)
      expect(response.body).to include(autre_administrateur.email)
      expect(response.body).to include('name="otp_attempt"')
    end

    context 'when the procedure has no administrateur left' do
      before { procedure.administrateurs_procedures.delete_all }

      it 'does not claim administrateurs it cannot name' do
        get :add_administrateur_and_instructeur_edit, params: { id: procedure.id }

        expect(response.body).not_to include('Administrateurs actuels')
      end
    end
  end

  describe '#add_administrateur_and_instructeur' do
    let(:super_admin) { create(:super_admin, :with_otp) }
    let(:otp_attempt) { current_otp_for(super_admin) }
    let(:procedure) { procedures.individual }

    subject { post :add_administrateur_and_instructeur, params: { id: procedure.id, otp_attempt: } }

    it_behaves_like "a manager action gated by a fresh super-admin OTP" do
      let!(:administrateur) { create(:administrateur, email: super_admin.email) }
      let(:other_procedure) { procedures.close }
      let(:action_matcher) { change { AdministrateursProcedure.where(administrateur:, manager: true).count } }
      let(:replay_subject) do
        -> { post :add_administrateur_and_instructeur, params: { id: other_procedure.id, otp_attempt: } }
      end
    end

    context "when the current super admin is not an administrateur and not an instructeur of the procedure" do
      before { administrateur }
      it "adds the current super admin as administrateur and instructeur to the procedure" do
        subject
        expect(procedure.administrateurs).to include(administrateur)
        expect(procedure.instructeurs).to include(administrateur.instructeur)
        expect(flash[:alert]).to be_nil
        expect(flash[:notice]).to eq("L’administrateur #{administrateur.email} a été ajouté à la démarche. L’instructeur #{administrateur.instructeur.email} a été ajouté à la démarche.")
      end
    end

    context "when the current super admin is an instructor of the procedure but not an administrator" do
      let!(:administrateur) { create(:administrateur, email: super_admin.email, instructeur: instructeur) }
      let(:instructeur) { create(:instructeur) }

      before do
        procedure.groupe_instructeurs.map do |groupe_instructeur|
          groupe_instructeur.add_instructeurs(emails: [instructeur.email])
        end
      end

      it "adds the current super admin as administrateur to the procedure" do
        subject
        expect(procedure.administrateurs).to include(administrateur)
        expect(procedure.instructeurs).to include(administrateur.instructeur)
        expect(flash[:alert]).to be_nil
        expect(flash[:notice]).to eq("L’administrateur #{administrateur.email} a été ajouté à la démarche. L’instructeur #{instructeur.email} a été ajouté à la démarche.")
      end
    end

    context "when the current super admin is an administrator of the procedure but not an instructor" do
      let(:procedure) { create(:procedure, administrateurs: [administrateur, autre_administrateur]) }

      it "adds the current super admin as instructor to the procedure" do
        subject
        expect(procedure.administrateurs).to include(administrateur)
        expect(procedure.instructeurs).to include(administrateur.instructeur)
        expect(flash[:alert]).to be_nil
        expect(flash[:notice]).to eq("L’administrateur #{administrateur.email} a été ajouté à la démarche. L’instructeur #{administrateur.instructeur.email} a été ajouté à la démarche.")
      end
    end
  end

  describe '#import_tags' do
    let(:procedure) { create(:procedure) }

    subject do
      post :import_tags, params: { id: procedure.id, tags_csv_file: csv_file }
    end

    context 'when the file is a valid CSV' do
      let(:csv_file) { fixture_file_upload('spec/fixtures/files/import-tags.csv', 'text/csv') }

      it 'redirects with a success notice' do
        subject
        expect(response).to redirect_to(manager_administrateurs_path)
        expect(flash[:notice]).to include("Import des tags terminé")
        expect(flash[:alert]).to be_nil
      end
    end

    context 'when the file content type is not accepted' do
      let(:csv_file) { fixture_file_upload('spec/fixtures/files/french-flag.gif', 'image/gif') }

      it 'rejects the file and redirects with an alert' do
        subject
        expect(response).to redirect_to(manager_administrateurs_path)
        expect(flash[:alert]).to eq("Importation impossible : veuillez importer un fichier CSV")
        expect(flash[:notice]).to be_nil
      end
    end

    context 'when a binary file is uploaded with a spoofed text/csv content type' do
      let(:csv_file) { fixture_file_upload('spec/fixtures/files/french-flag.gif', 'text/csv') }

      it 'rejects the file based on sniffed content type, not declared content type' do
        subject
        expect(response).to redirect_to(manager_administrateurs_path)
        expect(flash[:alert]).to eq("Importation impossible : veuillez importer un fichier CSV")
        expect(flash[:notice]).to be_nil
      end
    end

    context 'when the file exceeds max size' do
      let(:csv_file) { fixture_file_upload('spec/fixtures/files/import-tags.csv', 'text/csv') }

      before { allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(2.megabytes) }

      it 'rejects the file and redirects with an alert' do
        subject
        expect(response).to redirect_to(manager_administrateurs_path)
        expect(flash[:alert]).to eq("Importation impossible : le poids du fichier est supérieur à 1 Mo")
        expect(flash[:notice]).to be_nil
      end
    end
  end
end
