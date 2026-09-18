# frozen_string_literal: true

describe "ProConnect restriction of a procedure on the instructeur pages", type: :request do
  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.individual }
  # Another procedure of the instructeur, without restriction, whose id is put
  # in the url instead of the restricted one.
  let(:other_procedure) { procedures.close }
  let(:dossier) { dossiers.en_construction }

  before do
    procedure.update!(pro_connect_restriction: :instructeurs)
    instructeur.assign_to_procedure(other_procedure)
    login_as(instructeur.user, scope: :user)
  end

  shared_examples "a page requiring ProConnect" do
    it do
      subject

      expect(response).to redirect_to(pro_connect_required_path)
    end
  end

  describe "a dossier, reached through another procedure" do
    subject { get instructeur_dossier_path(other_procedure, dossier) }

    it_behaves_like "a page requiring ProConnect"
  end

  describe "the edition of a dossier, reached through another procedure" do
    before { procedure.update!(instructeurs_can_edit_dossiers: true) }

    subject { get edit_instructeur_dossier_path(other_procedure, dossier) }

    it_behaves_like "a page requiring ProConnect"
  end

  describe "the archives" do
    subject { get list_instructeur_archives_path(procedure) }

    it_behaves_like "a page requiring ProConnect"
  end

  describe "a batch operation" do
    subject do
      post instructeur_batch_operations_path(procedure),
        params: { batch_operation: { operation: BatchOperation.operations.fetch(:archiver), dossier_ids: [dossiers.accepte.id] } }
    end

    it_behaves_like "a page requiring ProConnect"

    it "does not create the batch operation" do
      expect { subject }.not_to change { instructeur.batch_operations.count }
    end
  end

  describe "the groupes instructeurs" do
    before { procedure.update!(instructeurs_self_management_enabled: true) }

    subject { get instructeur_groupe_path(procedure, procedure.defaut_groupe_instructeur) }

    it_behaves_like "a page requiring ProConnect"
  end

  describe "the export templates" do
    subject { get new_instructeur_procedure_export_template_path(procedure) }

    it_behaves_like "a page requiring ProConnect"
  end

  describe "an avis, reached through another procedure" do
    let(:pending_avis) { avis.pending }

    subject { patch revoquer_instructeur_avis_path(other_procedure, pending_avis) }

    it_behaves_like "a page requiring ProConnect"

    it "does not revoke the avis" do
      subject

      expect(Avis.exists?(pending_avis.id)).to be(true)
    end
  end

  describe "the filters of the procedure presentation" do
    let(:procedure_presentation) do
      instructeur.assign_to.find_by!(groupe_instructeur: procedure.defaut_groupe_instructeur)
        .procedure_presentation_or_default_and_errors.first
    end

    subject { get customize_filters_instructeur_procedure_presentation_path(procedure_presentation, statut: 'tous') }

    it_behaves_like "a page requiring ProConnect"
  end

  context "when the instructeur is logged in with ProConnect" do
    before do
      jar = ActionDispatch::TestRequest.create.cookie_jar
      jar.encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = { user_id: instructeur.user.id }.to_json
      cookies[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = jar[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME]
    end

    it "shows the dossier" do
      get instructeur_dossier_path(procedure, dossier)

      expect(response).to have_http_status(:ok)
    end
  end
end
