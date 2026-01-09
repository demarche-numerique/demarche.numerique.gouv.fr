# frozen_string_literal: true

describe Administrateurs::AttestationTemplatesController, type: :controller do
  let(:admin) { administrateurs(:default_admin) }
  let(:attestation_template) { build(:attestation_template) }
  let(:procedure) { create(:procedure, administrateur: admin, attestation_acceptation_template: attestation_template) }
  let(:logo) { fixture_file_upload('spec/fixtures/files/white.png', 'image/png') }
  let(:logo2) { fixture_file_upload('spec/fixtures/files/white.png', 'image/png') }
  let(:signature) { fixture_file_upload('spec/fixtures/files/black.png', 'image/png') }
  let(:signature2) { fixture_file_upload('spec/fixtures/files/black.png', 'image/png') }
  let(:invalid_logo) { fixture_file_upload('spec/fixtures/files/invalid_file_format.json', 'application/json') }

  before do
    procedure
    sign_in(admin.user)
    freeze_time
  end

  shared_examples 'rendering a PDF successfully' do
    render_views
    it 'renders a PDF' do
      expect(subject.status).to eq(200)
      expect(subject.media_type).to eq('application/pdf')
    end
  end

  describe 'GET #preview' do
    let(:attestation_params) do
      { title: 't', body: 'b', footer: 'f' }
    end

    before do
      get :preview,
        params: {
          procedure_id: procedure.id,
        }
    end

    context 'if an attestation template exists on the procedure' do
      context 'with images' do
        let(:attestation_template) { build(:attestation_template, attestation_params.merge(logo: logo, signature: signature)) }

        it do
          expect(assigns(:attestation)).to include(attestation_params)
          expect(assigns(:attestation)[:created_at]).to eq(Time.zone.now)
          expect(assigns(:attestation)[:logo].download).to eq(logo2.read)
          expect(assigns(:attestation)[:signature].download).to eq(signature2.read)
        end
        it_behaves_like 'rendering a PDF successfully'
      end

      context 'without images' do
        let(:attestation_template) { build(:attestation_template, attestation_params) }

        it do
          expect(assigns(:attestation)).to include(attestation_params)
          expect(assigns(:attestation)[:created_at]).to eq(Time.zone.now)
          expect(assigns(:attestation)[:logo]).to eq(nil)
          expect(assigns(:attestation)[:signature]).not_to be_attached
        end
        it_behaves_like 'rendering a PDF successfully'
      end

      context 'with empty footer' do
        let(:attestation_template) { build(:attestation_template, { title: 't', body: 'b', footer: nil }) }

        it_behaves_like 'rendering a PDF successfully'
      end

      context 'with large footer' do
        let(:attestation_params) { build(:attestation_template, { title: 't', body: 'b', footer: ' ' * 190 }) }

        it_behaves_like 'rendering a PDF successfully'
      end
    end
  end

  describe 'GET #edit' do
    before { get :edit, params: { procedure_id: procedure.id } }

    context 'if an attestation template exists on the procedure' do
      it do
        expect(subject.status).to eq(200)
        expect(assigns(:attestation_template)).to eq(attestation_template)
      end
    end

    context 'if an attestation template does not exist on the procedure' do
      let(:attestation_template) { nil }

      it do
        expect(subject.status).to eq(200)
        expect(assigns(:attestation_template).id).to be_nil
        expect(assigns(:attestation_template)).to be_an_instance_of(AttestationTemplate)
      end
    end
  end

  describe 'POST #create' do
    let(:attestation_template) { nil }
    let(:attestation_params) { { title: 't', body: 'b', footer: 'f', activated: true, kind: 'acceptation' } }

    context 'nominal' do
      before do
        post :create,
          params: {
            procedure_id: procedure.id,
            attestation_template: attestation_params.merge(logo: logo, signature: signature),
          }
      end

      it do
        expect(procedure.attestation_acceptation_template).to have_attributes(attestation_params)
        expect(procedure.attestation_acceptation_template.activated).to be true
        expect(procedure.attestation_acceptation_template.logo.download).to eq(logo2.read)
        expect(procedure.attestation_acceptation_template.signature.download).to eq(signature2.read)
        expect(procedure.attestation_acceptation_template.kind).to eq('acceptation')
        expect(response).to redirect_to edit_admin_procedure_attestation_template_path(procedure)
        expect(flash.notice).to eq("Le modèle de l’attestation a bien été enregistré")
      end
    end

    context 'when something wrong happens in the attestation template creation' do
      let(:invalid_footer) { 'f' * 200 }
      let(:attestation_params) { { title: 't', body: 'b', footer: invalid_footer, activated: true } }

      before do
        post :create,
          params: {
            procedure_id: procedure.id,
            attestation_template: attestation_params,
          }
      end

      it do
        expect(flash.alert).to be_present
        expect(procedure.attestation_acceptation_template).to be nil
      end
    end

    context 'when procedure is published' do
      let(:procedure) { create(:procedure, :published, administrateur: admin) }
      let(:attestation_template) { nil }
      let(:attestation_params) { { title: 't', body: 'b', footer: '', activated: true, kind: 'acceptation' } }
      let(:revisions_enabled) { false }

      before do
        if revisions_enabled
          Flipper.enable(:procedure_revisions, procedure)
        end

        post :create,
          params: {
            procedure_id: procedure.id,
            attestation_template: attestation_params,
          }
      end

      it do
        expect(procedure.attestation_acceptation_template).to eq(procedure.attestation_acceptation_template)
        expect(procedure.attestation_acceptation_template.title).to eq('t')
      end
    end
  end

  describe 'PATCH #update' do
    let(:attestation_params) { { title: 't', body: 'b', footer: 'f' } }
    let(:attestation_params_with_images) { attestation_params.merge(logo: logo, signature: signature) }

    context 'nominal' do
      before do
        patch :update,
          params: {
            procedure_id: procedure.id,
            attestation_template: attestation_params_with_images,
          }
      end

      it do
        expect(procedure.attestation_acceptation_template).to have_attributes(attestation_params)
        expect(procedure.attestation_acceptation_template.logo.download).to eq(logo2.read)
        expect(procedure.attestation_acceptation_template.signature.download).to eq(signature2.read)
        expect(response).to redirect_to edit_admin_procedure_attestation_template_path(procedure)
        expect(flash.notice).to eq("Le modèle de l’attestation a bien été modifié")
      end
    end

    context 'when procedure is published' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text }, { type: :text }, { type: :text }], administrateur: admin, attestation_acceptation_template: attestation_template) }
      let(:dossier) {}
      let(:attestation_template) { build(:attestation_template, title: 'a') }
      let(:attestation_params) do
        {
          title: title,
          body: body,
          footer: '',
          activated: true,
        }
      end
      let(:type_de_champ) { procedure.draft_revision.types_de_champ_public[0] }
      let(:removed_type_de_champ) { procedure.draft_revision.types_de_champ_public[1] }
      let(:removed_and_published_type_de_champ) { procedure.draft_revision.types_de_champ_public[2] }
      let(:new_type_de_champ) { procedure.draft_revision.types_de_champ_public.find { _1.libelle == 'new type de champ' } }
      let(:draft_type_de_champ) { procedure.draft_revision.types_de_champ_public.find { _1.libelle == 'draft type de champ' } }
      let(:title) { 'title --numéro du dossier--' }
      let(:body) { "body --#{type_de_champ.libelle}-- et --#{new_type_de_champ.libelle}--" }

      before do
        procedure.publish!(procedure.administrateurs.first)
        procedure.reload
        procedure.draft_revision.remove_type_de_champ(removed_and_published_type_de_champ.stable_id)
        procedure.draft_revision.add_type_de_champ(libelle: 'new type de champ', type_champ: 'text', after_stable_id: procedure.draft_revision.types_de_champ_public.last.stable_id)
        procedure.publish_revision!(admin)
        procedure.reload
        procedure.draft_revision.remove_type_de_champ(removed_type_de_champ.stable_id)
        procedure.draft_revision.reload
        procedure.draft_revision.add_type_de_champ(libelle: 'draft type de champ', type_champ: 'text', after_stable_id: procedure.draft_revision.types_de_champ_public.last.stable_id)

        dossier

        patch :update,
          params: {
            procedure_id: procedure.id,
            attestation_template: attestation_params,
          }
      end

      context 'normal' do
        it do
          expect(response).to redirect_to edit_admin_procedure_attestation_template_path(procedure)
          expect(procedure.attestation_acceptation_template.title).to eq(title)
          expect(procedure.attestation_acceptation_template.body).to eq(body)
        end
      end

      context 'with invalid tag' do
        let(:body) { 'body --yolo--' }
        it { expect(flash.alert).to eq("Le modèle de l’attestation contient des erreurs et n’a pas pu être enregistré. Veuiller les corriger") }
      end

      context 'with removed champ' do
        render_views
        let(:body) { "body --#{removed_type_de_champ.libelle}--" }

        it { expect(response.body).to have_content("Le champ « Contenu de l’attestation » contient la balise \"#{removed_type_de_champ.libelle}\" qui a été supprimée dans les modifications en cours du formulaire. Supprimer cette balise ou réinitialiser les modifications du formulaire puis recommencer") }
      end

      context 'with removed and published' do
        render_views
        let(:body) { "body --#{removed_and_published_type_de_champ.libelle}--" }
        it { expect(response.body).to have_content("Le champ « Contenu de l’attestation » contient la balise \"#{removed_and_published_type_de_champ.libelle}\" qui a été supprimée.") }
      end

      context 'with new champ missing on dossier submitted on previous revision' do
        render_views
        let(:dossier) { create(:dossier, :en_construction, procedure: procedure, revision: procedure.revisions.first) }
        let(:body) { "body --#{new_type_de_champ.libelle}--" }
        it { expect(response.body).to have_content("Le champ « Contenu de l’attestation » contient la balise \"#{new_type_de_champ.libelle}\" qui n’existe pas sur un des dossiers en cours de traitement") }
      end

      context 'with champ on draft' do
        render_views
        let(:body) { "body --#{draft_type_de_champ.libelle}--" }
        it { expect(response.body).to have_content("Le champ « Contenu de l’attestation » contient la balise \"#{draft_type_de_champ.libelle}\" qui n’est pas encore publiée") }
      end
    end
  end
end
