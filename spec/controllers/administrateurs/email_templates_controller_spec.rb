# frozen_string_literal: true

describe Administrateurs::EmailTemplatesController, type: :controller do
  render_views
  let(:procedure) { procedures.individual }

  let(:admin) { administrateurs.default }

  before do
    sign_in(admin.user)
  end

  describe 'GET index' do
    render_views

    subject { get :index, params: { procedure_id: procedure.id } }

    it '', :slow do
      expect(subject.status).to eq 200
      expect(subject.body).to include("Modèles d’email")
      expect(subject.body).to include(Emails::Depose::DISPLAYED_NAME)
      expect(subject.body).not_to include('Démarche déclarative')
    end

    context 'quand la démarche est déclarative' do
      before { procedure.update!(declarative_with_state: :accepte) }

      it 'annonce le paramétrage déclaratif et renvoie vers la présentation', :slow do
        expect(subject.body).to include('Démarche déclarative')
        expect(subject.body).to include("passage automatique au statut «\u{a0}accepté\u{a0}»")
        expect(subject.body).to include(edit_admin_procedure_path(procedure, section: 'options-avancees', anchor: 'declarative_with_state-legend'))
      end

      context 'et qu’elle utilise l’accusé de lecture' do
        before { procedure.update!(accuse_lecture: true) }

        it 'signale que l’accusé de réception annonce quand même l’acceptation', :slow do
          expect(subject.body).to include('la décision finale reste masquée')
          expect(subject.body).to include('annonce toutefois cette acceptation')
        end
      end
    end

    context 'quand la démarche utilise l’accusé de lecture sans être déclarative' do
      before { procedure.update!(accuse_lecture: true) }

      it 'ne promet le masquage de la décision que sur les emails non modifiables', :slow do
        expect(subject.body).to include('la décision finale reste masquée')
        expect(subject.body).not_to include('annonce toutefois cette acceptation')
      end
    end
  end

  describe '#preview' do
    let_it_be(:procedure) { create(:procedure, :with_logo, :with_service, administrateur: administrateurs.default) }

    before do
      get :preview, params: { id: "depose", procedure_id: procedure.id }
    end

    it { expect(response).to have_http_status(:ok) }

    it 'displays the procedure logo' do
      expect(response.body).to have_css("img[src*='/rails/active_storage/blobs/']")
    end

    it 'displays the action buttons' do
      expect(response.body).to have_link('Consulter mon dossier')
    end

    it 'displays the service in the footer' do
      expect(response.body).to include(procedure.service.nom)
      expect(response.body).to include(procedure.service.telephone)
    end
  end

  describe 'PUT #update (tiptap)' do
    let(:json_body) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Salut" }] }] }.to_json }
    let(:json_subject) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Objet" }] }] }.to_json }

    it 'enregistre json_body et json_subject' do
      put :update, params: {
        procedure_id: procedure.id, id: 'passe_en_instruction',
        email_template: { tiptap_body: json_body, tiptap_subject: json_subject },
      }
      mail = procedure.reload.email_passe_en_instruction
      expect(mail.json_body).to eq(JSON.parse(json_body))
      expect(mail.json_subject).to eq(JSON.parse(json_subject))
    end

    it 'accepte le param_key par type d’un formulaire rendu avant l’unification' do
      put :update, params: {
        procedure_id: procedure.id, id: 'passe_en_instruction',
        emails_passe_en_instruction: { tiptap_body: json_body, tiptap_subject: json_subject },
      }
      expect(procedure.reload.email_passe_en_instruction.json_body).to eq(JSON.parse(json_body))
    end

    it 'enregistre la personnalisation sur le type du réglage déclaratif' do
      procedure.update!(declarative_with_state: :accepte)

      put :update, params: {
        procedure_id: procedure.id, id: 'depose',
        email_template: { tiptap_body: json_body, tiptap_subject: json_subject },
      }
      expect(procedure.reload.email_depose).to be_an_instance_of(Emails::DeposeEtAccepte)
      expect(procedure.email_depose.json_body).to eq(JSON.parse(json_body))
    end

    it 'accepte le param_key d’un formulaire rendu avant la bascule déclarative' do
      procedure.update!(declarative_with_state: :accepte)

      put :update, params: {
        procedure_id: procedure.id, id: 'depose',
        emails_depose: { tiptap_body: json_body, tiptap_subject: json_subject },
      }
      expect(procedure.reload.email_depose).to be_an_instance_of(Emails::DeposeEtAccepte)
      expect(procedure.email_depose.json_body).to eq(JSON.parse(json_body))
    end

    context 'quand le contenu référence un tag invalide' do
      let(:invalid_subject) do
        {
          "type" => "doc",
          "content" => [
            {
              "type" => "paragraph",
              "content" => [
                { "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } },
                { "type" => "mention", "attrs" => { "id" => "unknown_tag", "label" => "Inconnu" } },
              ],
            },
          ],
        }.to_json
      end

      it 'ré-affiche l’éditeur avec l’aperçu sans planter et n’enregistre pas' do
        put :update, params: {
          procedure_id: procedure.id, id: 'passe_en_instruction',
          email_template: { tiptap_subject: invalid_subject },
        }
        expect(response).to have_http_status(:ok)
        expect(procedure.reload.email_passe_en_instruction).to be_nil
      end
    end
  end

  describe 'GET edit' do
    subject { get :edit, params: { procedure_id: procedure.id, id: 'passe_en_instruction' } }

    it { expect(subject).to have_http_status(:ok) }

    it 'affiche l’éditeur d’objet en une ligne' do
      expect(subject.body).to include('data-tiptap-single-line-value')
    end

    it 'affiche l’aperçu du sujet et du corps' do
      expect(subject.body).to include('id="mail-body-preview"')
      expect(subject.body).to include('id="mail-subject-preview"')
    end
  end

  describe 'GET edit (alerte d’incohérence attestation)' do
    let(:attestation) { nil }
    let(:procedure) { create(:procedure, administrateur: admin, declarative_with_state: :accepte, attestation_acceptation_template: attestation) }

    context 'quand l’attestation est active mais le modèle combiné ne la mentionne pas' do
      let(:attestation) { build(:attestation_template, activated: true, kind: :acceptation) }

      before { create(:email_depose_et_accepte, procedure:, body: 'sans balise') }

      it 'alerte sur la page du modèle combiné' do
        get :edit, params: { procedure_id: procedure.id, id: 'depose' }
        expect(response.body).to include('Cette démarche comporte une attestation')
      end
    end

    context 'quand seul le modèle combiné mentionne une attestation inexistante' do
      before { create(:email_depose_et_accepte, procedure:, body: '--lien attestation--') }

      it 'désigne le modèle combiné depuis la page de l’accusé d’acceptation' do
        get :edit, params: { procedure_id: procedure.id, id: 'accepte' }
        expect(response.body).to include('Cette démarche ne comporte pas d’attestation')
        expect(response.body).to include(edit_admin_procedure_email_template_path(procedure, 'depose'))
      end
    end
  end

  describe 'POST #preview (turbo_stream)' do
    let(:json_body) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Salut" }] }] }.to_json }

    it 'renvoie un turbo_stream mettant à jour l’aperçu du corps' do
      post :preview, params: {
        procedure_id: procedure.id, id: 'passe_en_instruction',
        email_template: { tiptap_body: json_body },
      }, format: :turbo_stream
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('mail-body-preview')
      expect(response.body).to include('Salut')
    end
  end
end
