# frozen_string_literal: true

describe Manager::ProceduresController, type: :controller do
  let(:super_admin) { create :super_admin }
  let(:administrateur) { create(:administrateur, email: super_admin.email) }
  let(:autre_administrateur) { administrateurs(:default_admin) }
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

    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :repetition, children: [{ type: :text, libelle: 'sub type de champ' }] }]) }

    before do
      get :show, params: { id: procedure.id }
    end

    it do
      expect(response.body).to include('sub type de champ')
      expect(response.body).to include('Hidden At As Template')
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
      let!(:dossier) { create(:dossier) }

      before do
        get :index, params: { procedure: { direction: :asc, order: :dossiers } }
      end

      it { expect(response.body).to include('1 Dossier') }
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

  describe '#add_administrateur_and_instructeur' do
    let(:procedure) { create(:procedure, administrateurs: [autre_administrateur]) }
    subject { post :add_administrateur_and_instructeur, params: { id: procedure.id } }

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
end
