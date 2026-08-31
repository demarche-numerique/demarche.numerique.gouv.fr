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
