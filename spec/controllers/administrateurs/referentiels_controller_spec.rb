# frozen_string_literal: true

describe Administrateurs::ReferentielsController, type: :controller do
  let(:stable_id) { 123 }
  let(:types_de_champ_public) { [{ type: :referentiel, stable_id: }] }
  let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private:) }
  let(:types_de_champ_private) { [] }

  before { sign_in(procedure.administrateurs.first.user) }

  describe 'IDOR on retrieve_referentiel (edit/update)' do
    let(:other_referentiel) { create(:api_referentiel, :exact_match, :with_authentication_data) }
    let(:other_procedure) { create(:procedure, types_de_champ_public: [{ type: :referentiel, referentiel: other_referentiel }]) }
    let(:other_admin) { other_procedure.administrateurs.first }

    it 'blocks reading another admin referentiel via edit' do
      expect {
        get :edit, params: { procedure_id: procedure.id, stable_id:, id: other_referentiel.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'blocks modifying another admin referentiel via update' do
      expect {
        patch :update, params: {
          procedure_id: procedure.id, stable_id:, id: other_referentiel.id,
          referentiel: { hint: 'hacked' },
        }, format: :turbo_stream
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'IDOR on build_or_clone_by_id_params (clone credentials)' do
    let(:other_referentiel) { create(:api_referentiel, :exact_match, :with_authentication_data) }
    let(:other_procedure) { create(:procedure, types_de_champ_public: [{ type: :referentiel, referentiel: other_referentiel }]) }
    let(:other_admin) { other_procedure.administrateurs.first }

    it 'blocks cloning authentication_data from another admin referentiel' do
      expect {
        get :new, params: { procedure_id: procedure.id, stable_id:, referentiel_id: other_referentiel.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#new' do
    it 'renders successifully' do
      get :new, params: { procedure_id: procedure.id, stable_id: }
      expect(response).to have_http_status(:success)
    end

    context 'given a referentiel_id' do
      let(:original_data) do
        {
          hint: 'howtofillme',
          mode: 'exact_match',
        }
      end
      let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }
      let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ], **original_data) }

      it 'clone existing one' do
        get :new, params: { procedure_id: procedure.id, referentiel_id: referentiel.id, stable_id: }
        cloned = assigns(:referentiel)
        expect(cloned.hint).to eq(original_data[:hint])
        expect(cloned.mode).to eq(original_data[:mode])
        expect(cloned.url_tiptap).to eq(referentiel.url_tiptap)
        expect(cloned.test_data_tiptap).to eq(referentiel.test_data_tiptap)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe '#create' do
    context 'partial update (selecting type)' do
      subject { post :create, params: { procedure_id: procedure.id, stable_id:, referentiel: referentiel_params, commit:	"Étape+suivante" }, format: :turbo_stream }
      let(:referentiel_params) { { type: 'Referentiels::APIReferentiel' } }
      it 're-render form' do
        expect { subject }.not_to change { Referentiel.count }
        expect(response).to have_http_status(:success)
      end
    end

    context 'partial update (autosave with tiptap url, hint etc...)' do
      subject { post :create, params: { procedure_id: procedure.id, stable_id:, referentiel: referentiel_params }, format: :turbo_stream }

      let(:url_tiptap_json) do
        {
          type: "doc",
          content: [
            {
              type: "paragraph",
              content: [
                { type: "text", text: "https://rnb-api.beta.gouv.fr/api/alpha/buildings/" },
                { type: "mention", attrs: { id: "{query}", label: "Valeur saisie par l'usager" } },
              ],
            },
          ],
        }
      end

      let(:referentiel_params) do
        {
          type: 'Referentiels::APIReferentiel',
          mode: 'exact_match',
          url_tiptap: url_tiptap_json.to_json,
          hint: 'Identifiant unique du bâtiment dans le RNB, composé de 12 chiffre et lettre',
          test_data_tiptap: { "{query}" => "PG46YY6YWCX8" },
          authentication_data: { header: 'Authorization', value: 'Bearer secret-token' },
          authentication_method: 'header_token',
        }
      end

      it 'creates referentiel and continue live edition' do
        expect { subject }.to change { Referentiel.count }.by(1)

        referentiel = Referentiel.first

        expect(response).to have_http_status(:success)

        expect(referentiel.types_de_champ).to include(TypeDeChamp.find_by(stable_id:))
        expect(referentiel.type).to eq(referentiel_params[:type])
        expect(referentiel.mode).to eq(referentiel_params[:mode])
        expect(referentiel.url_tiptap).to eq(url_tiptap_json.deep_stringify_keys)
        expect(referentiel.hint).to eq(referentiel_params[:hint])
        expect(referentiel.test_data_tiptap).to eq(referentiel_params[:test_data_tiptap])
        expect(referentiel.authentication_data.with_indifferent_access).to eq(referentiel_params[:authentication_data].with_indifferent_access)
        expect(referentiel.authentication_method).to eq(referentiel_params[:authentication_method])
      end
    end

    context 'with commit params (submit save)' do
      subject { post :create, params: { commit: 'Étape suivante', procedure_id: procedure.id, stable_id:, referentiel: referentiel_params }, format: :turbo_stream }

      let(:url_tiptap_json) do
        {
          type: "doc",
          content: [
            {
              type: "paragraph",
              content: [
                { type: "text", text: "https://rnb-api.beta.gouv.fr/api/alpha/buildings/" },
                { type: "mention", attrs: { id: "{query}", label: "Valeur saisie par l'usager" } },
              ],
            },
          ],
        }
      end

      context 'when referentiel is exact_match' do
        let(:referentiel_params) do
          {
            type: 'Referentiels::APIReferentiel',
            mode: 'exact_match',
            url_tiptap: url_tiptap_json.to_json,
            hint: 'Identifiant unique du bâtiment dans le RNB, composé de 12 chiffre et lettre',
              test_data_tiptap: { "{query}" => "PG46YY6YWCX8" },
          }
        end

        it 'creates referentiel and continue redirect' do
          expect { subject }.to change { Referentiel.count }.by(1)

          referentiel = Referentiel.first

          expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, stable_id, referentiel))

          expect(referentiel.types_de_champ).to include(TypeDeChamp.find_by(stable_id:))
          expect(referentiel.type).to eq(referentiel_params[:type])
          expect(referentiel.mode).to eq(referentiel_params[:mode])
          expect(referentiel.url_tiptap).to eq(url_tiptap_json.deep_stringify_keys)
          expect(referentiel.hint).to eq(referentiel_params[:hint])
          expect(referentiel.test_data_tiptap).to eq(referentiel_params[:test_data_tiptap])
        end
      end

      context 'when referentiel is autocomplete' do
        let(:referentiel_params) do
          {
            type: 'Referentiels::APIReferentiel',
            mode: 'autocomplete',
            url_tiptap: url_tiptap_json.to_json,
            hint: 'Identifiant unique du bâtiment dans le RNB, composé de 12 chiffre et lettre',
              test_data_tiptap: { "{query}" => "PG46YY6YWCX8" },
          }
        end

        it 'creates referentiel and continue redirect' do
          expect { subject }.to change { Referentiel.count }.by(1)

          referentiel = Referentiel.first

          expect(response).to redirect_to(autocomplete_configuration_admin_procedure_referentiel_path(procedure, stable_id, referentiel))

          expect(referentiel.types_de_champ).to include(TypeDeChamp.find_by(stable_id:))
          expect(referentiel.type).to eq(referentiel_params[:type])
          expect(referentiel.mode).to eq(referentiel_params[:mode])
          expect(referentiel.url_tiptap).to eq(url_tiptap_json.deep_stringify_keys)
          expect(referentiel.hint).to eq(referentiel_params[:hint])
          expect(referentiel.test_data_tiptap).to eq(referentiel_params[:test_data_tiptap])
        end
      end
    end
  end

  describe '#create with tiptap' do
    let(:url_tiptap_json) do
      {
        type: "doc",
        content: [
          {
            type: "paragraph",
                    content: [
                      { type: "text", text: "https://tabular-api.data.gouv.fr/api/resources/" },
                      { type: "mention", attrs: { id: "{query}", label: "Valeur saisie par l’usager" } },
                      { type: "text", text: "/" },
                      { type: "mention", attrs: { id: "tdc#{stable_id}", label: "Texte court" } },
                    ],
          },
        ],
      }
    end

    context 'partial update (autosave with tiptap params)' do
      subject { post :create, params: { procedure_id: procedure.id, stable_id:, referentiel: referentiel_params }, format: :turbo_stream }

      let(:referentiel_params) do
        {
          type: 'Referentiels::APIReferentiel',
          mode: 'exact_match',
          url_tiptap: url_tiptap_json.to_json,
          hint: 'Identifiant FINESS',
          test_data_tiptap: { "{query}" => "0100026", "tdc#{stable_id}" => "ABC123" },
        }
      end

      it 'creates referentiel with tiptap data' do
        expect { subject }.to change { Referentiel.count }.by(1)

        referentiel = Referentiel.last
        expect(response).to have_http_status(:success)
        expect(referentiel.url_tiptap).to eq(url_tiptap_json.deep_stringify_keys)
        expect(referentiel.test_data_tiptap).to eq({ "{query}" => "0100026", "tdc#{stable_id}" => "ABC123" })
        expect(referentiel.hint).to eq('Identifiant FINESS')
        expect(referentiel.mode).to eq('exact_match')
      end
    end

    context 'with commit params (submit save)' do
      subject { post :create, params: { commit: 'Étape suivante', procedure_id: procedure.id, stable_id:, referentiel: referentiel_params }, format: :turbo_stream }

      let(:referentiel_params) do
        {
          type: 'Referentiels::APIReferentiel',
          mode: 'exact_match',
          url_tiptap: url_tiptap_json.to_json,
          hint: 'Identifiant FINESS',
          test_data_tiptap: { "{query}" => "0100026", "tdc#{stable_id}" => "ABC123" },
        }
      end

      it 'creates referentiel and redirects' do
        expect { subject }.to change { Referentiel.count }.by(1)

        referentiel = Referentiel.last
        expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, stable_id, referentiel))
        expect(referentiel.url_tiptap).to eq(url_tiptap_json.deep_stringify_keys)
        expect(referentiel.test_data_tiptap).to eq({ "{query}" => "0100026", "tdc#{stable_id}" => "ABC123" })
      end
    end
  end

  describe '#clone with tiptap' do
    let(:original_tiptap_data) do
      {
        url_tiptap: {
          "type" => "doc", "content" => [
            {
              "type" => "paragraph", "content" => [
                { "type" => "text", "text" => "https://api.gouv.fr/" },
                { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } },
              ],
            },
          ],
        },
        test_data_tiptap: { "{query}" => "test" },
        hint: 'clone me',
        mode: 'exact_match',
      }
    end
    let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }
    let(:referentiel) { create(:api_referentiel, types_de_champ: [type_de_champ], **original_tiptap_data) }

    it 'clones tiptap columns' do
      get :new, params: { procedure_id: procedure.id, referentiel_id: referentiel.id, stable_id: }
      cloned = assigns(:referentiel)
      expect(cloned.url_tiptap).to eq(original_tiptap_data[:url_tiptap])
      expect(cloned.test_data_tiptap).to eq(original_tiptap_data[:test_data_tiptap])
      expect(response).to have_http_status(:success)
    end
  end

  describe "#edit" do
    let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }
    let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }

    it 'works' do
      get :edit, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "#update" do
    let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }
    let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }

    context 'partial update (updating hint only)' do
      subject { patch :update, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id, referentiel: referentiel_params }, format: :turbo_stream }

      let(:referentiel_params) { { hint: 'Nouvel indice' } }

      it 'updates the referentiel and re-renders the form' do
        expect { subject }.to change { referentiel.reload.hint }.to('Nouvel indice')
        expect(response).to have_http_status(:success)

        referentiel.reload

        expect(referentiel.hint).to eq(referentiel_params[:hint])
      end
    end

    context 'full update (updating all attributes) without autosave' do
      subject { patch :update, params: { commit: 'Étape suivante', procedure_id: procedure.id, stable_id:, id: referentiel.id, referentiel: referentiel_params }, format: :turbo_stream }
      let(:new_url_tiptap) do
        { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "https://rnb-api.beta.gouv.fr/api/alpha/buildings/" }, { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } }] }] }
      end
      let(:referentiel) do
        create(
          :api_referentiel,
          :exact_match,
          :with_exact_match_response,
          types_de_champ: [type_de_champ],
            datasource: '$.jsonpath',
          tiptap_template: { "type": "doc", "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "{{jsonpath}}" }] }] }.to_json
        )
      end
      before do
        type_de_champ.update(referentiel_mapping: { "old" => { type: "string" } })
      end

      let(:referentiel_params) do
        {
          mode: 'exact_match',
          url_tiptap: new_url_tiptap.to_json,
          hint: 'Identifiant unique du bâtiment dans le RNB',
          test_data_tiptap: { "{query}" => "PG46YY6YWCX8" },
        }
      end

      it 'updates the referentiel and redirects' do
        subject

        # redirect is ok
        expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, stable_id, referentiel))

        # ensure data is saved
        referentiel.reload
        expect(referentiel.mode).to eq(referentiel_params[:mode])
        expect(referentiel.url_tiptap).to eq(new_url_tiptap)
        expect(referentiel.hint).to eq(referentiel_params[:hint])
        expect(referentiel.test_data_tiptap).to eq({ "{query}" => "PG46YY6YWCX8" })

        # also reset last_response/referentiel_mapping when url changed
        expect(referentiel.last_response).to be_nil
        expect(referentiel.autocomplete_configuration).to eq({ "json_template" => {} })
        expect(type_de_champ.reload.referentiel_mapping).to eq({})
      end
    end
  end

  describe '#update with tiptap' do
    let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }
    let(:initial_url_tiptap) do
      {
        "type" => "doc", "content" => [
          {
            "type" => "paragraph", "content" => [
              { "type" => "text", "text" => "https://api.gouv.fr/old" },
              { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } },
            ],
          },
        ],
      }
    end
    let(:referentiel) do
      create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ],
        url_tiptap: initial_url_tiptap,
        test_data_tiptap: { "{query}" => "old_value" })
    end

    context 'partial update (autosave hint only)' do
      subject { patch :update, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id, referentiel: { hint: 'Updated hint' } }, format: :turbo_stream }

      it 'updates hint without clearing cache' do
        subject
        referentiel.reload
        expect(referentiel.hint).to eq('Updated hint')
        expect(referentiel.url_tiptap).to eq(initial_url_tiptap)
        expect(response).to have_http_status(:success)
      end
    end

    context 'full update with url_tiptap change triggers cache bust' do
      let(:new_url_tiptap) do
        { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "https://api.gouv.fr/new/" }, { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } }] }] }
      end
      let(:referentiel) do
        create(:api_referentiel, :exact_match, :with_exact_match_response, types_de_champ: [type_de_champ],
            url_tiptap: initial_url_tiptap,
          test_data_tiptap: { "{query}" => "old_value" },
          datasource: '$.jsonpath',
          tiptap_template: { "type": "doc", "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "tpl" }] }] }.to_json)
      end

      before { type_de_champ.update(referentiel_mapping: { "old" => { type: "string" } }) }

      subject do
        patch :update, params: {
          commit: 'Étape suivante',
          procedure_id: procedure.id, stable_id:, id: referentiel.id,
          referentiel: {
            mode: 'exact_match',
            url_tiptap: new_url_tiptap.to_json,
            hint: 'New hint',
            test_data_tiptap: { "{query}" => "new_value" },
          },
        }, format: :turbo_stream
      end

      it 'updates tiptap data and busts cache' do
        subject
        referentiel.reload

        expect(referentiel.url_tiptap).to eq(new_url_tiptap)
        expect(referentiel.test_data_tiptap).to eq({ "{query}" => "new_value" })
        expect(referentiel.hint).to eq('New hint')

        # cache bust
        expect(referentiel.last_response).to be_nil
        expect(referentiel.autocomplete_configuration).to eq({ "json_template" => {} })
        expect(type_de_champ.reload.referentiel_mapping).to eq({})

        expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, stable_id, referentiel))
      end
    end
  end

  describe '#validate_url' do
    subject { patch :validate_url, params: { procedure_id: procedure.id, stable_id:, referentiel: referentiel_params }, format: :turbo_stream }

    context 'with tiptap url containing mentions' do
      let(:referentiel_params) do
        {
          url_tiptap: {
            type: "doc",
            content: [
              {
                type: "paragraph",
                            content: [
                              { type: "text", text: "https://api.gouv.fr/" },
                              { type: "mention", attrs: { id: "{query}", label: "Query" } },
                            ],
              },
            ],
          }.to_json,
        }
      end

      it 'returns turbo_stream with validation feedback and test_data fields' do
        subject
        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('url-validation-feedback')
        expect(response.body).to include('test-data-fields')
      end
    end
  end

  describe "configuration_error" do
    let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }
    let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }

    it 'works' do
      allow_any_instance_of(Referentiels::APIReferentiel).to receive(:save).and_return(false)
      get :configuration_error, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe '#mapping_type_de_champ' do
    let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }

    context 'when referentiel not ready' do
      let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }

      it 'redirects to configuration error' do
        allow_any_instance_of(ReferentielService).to receive(:validate_referentiel).and_return(false)
        get :mapping_type_de_champ, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id }
        expect(response).to redirect_to(configuration_error_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel))
      end
    end

    context "when referentiel is ready" do
      let(:referentiel) { create(:api_referentiel, :exact_match, :with_exact_match_response, types_de_champ: [type_de_champ]) }

      before do
        allow_any_instance_of(API::Client)
          .to receive(:call).with(anything).and_return(stub_response)
      end

      context 'test APIReferentiel return valid response' do
        let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }
        include Dry::Monads[:result]
        OK = Data.define(:body, :response)

        let(:body) { {} }
        let(:http_response) { {} }
        let(:stub_response) { Success(OK[body, http_response]) }

        it 'renders' do
          expect { get :mapping_type_de_champ, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id } }
            .to change { referentiel.reload.last_response }.from(nil).to({ "body" => {}, "status" => 200 })
          expect(response).to have_http_status(200)
        end
      end
    end
  end

  describe '#update_mapping_type_de_champ' do
    let(:initial_mapping) do
      {
        "$.jsonpath" => {
          type: "type",
          prefill: "1",
          display_usager: "1",
          display_instructeur: "1",
        },
      }
    end
    let(:types_de_champ_public) { [{ type: :referentiel, stable_id:, referentiel_mapping: initial_mapping }] }
    let(:type_de_champ) { procedure.draft_revision.types_de_champ.find { _1.stable_id == stable_id } }
    let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }
    subject do
      patch :update_mapping_type_de_champ, params: {
        procedure_id: procedure.id,
            stable_id: stable_id,
            id: referentiel.id,
            type_de_champ: { referentiel_mapping: payload_referentiel_mapping },
      }
    end

    context 'when prefill is not in payload due to checkbox' do
      let(:payload_referentiel_mapping) { { "$.jsonpath" => { type: "type", libelle: "libelle" } } }
      it 'deep_merge payload so we do not have to resend all config always' do
        subject
        expect(type_de_champ.reload.referentiel_mapping["$.jsonpath"]["prefill"]).to eq("1")
        expect(type_de_champ.reload.referentiel_mapping["$.jsonpath"]["display_usager"]).to eq("1")
        expect(type_de_champ.reload.referentiel_mapping["$.jsonpath"]["display_instructeur"]).to eq("1")
      end
    end

    context 'when send partial payload' do
      let(:payload_referentiel_mapping) { { "$.jsonpath" => { type: "type", prefill: "prefill", libelle: "libelle" } } }
      it 'updates type_de_champ referentiel_mapping by deep_merging and redirects to prefill_and_display' do
        expect { subject }
          .to change { type_de_champ.reload.referentiel_mapping }
          .from(initial_mapping)
          .to(initial_mapping.deep_merge(payload_referentiel_mapping))
        expect(response).to redirect_to(prefill_and_display_admin_procedure_referentiel_path(procedure, stable_id, referentiel))
        expect(flash[:notice]).to eq("La configuration du mapping a bien été enregistrée")
      end
    end

    context 'when update fails' do
      let(:payload_referentiel_mapping) { { "$.jsonpath" => { type: "type" } } }

      before { allow_any_instance_of(TypeDeChamp).to receive(:update).and_return(false) }

      it 'redirects to mapping_type_de_champ_admin_procedure_referentiel_path with alert' do
        subject
        expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, stable_id, referentiel))
        expect(flash[:alert]).to eq("Une erreur est survenue")
      end
    end
  end

  describe '#prefill_and_display' do
    let(:payload_referentiel_mapping) do
      {
        "$.jsonpath" => {
          type: "type",
          prefill: "prefill",
          libelle: "libelle",
        },
      }
    end
    let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }
    let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }

    context 'when admin not signed in' do
      before { sign_out(procedure.administrateurs.first.user) }
      it 'redirects to the login page' do
        get :prefill_and_display, params: { procedure_id: procedure.id, stable_id: type_de_champ.stable_id, id: referentiel.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when admin signed in' do
      it 'returns http success' do
        get :prefill_and_display, params: { procedure_id: procedure.id, stable_id: type_de_champ.stable_id, id: referentiel.id }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe '#update_prefill_and_display_type_de_champ' do
    let(:types_de_champ_public) do
      [
        { type: :referentiel, stable_id: stable_id, referentiel_mapping: },
        { type: :text, stable_id: prefillable_stable_id },
      ]
    end
    let(:types_de_champ_private) { [] }

    let(:stable_id) { 1 }
    let(:prefillable_stable_id) { 2 }

    let(:type_de_champ) { procedure.draft_revision.types_de_champ.find(&:referentiel?) }
    let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }

    let(:referentiel_mapping) do
      {
        "$.jsonpath1" => {
          "type" => "Chaine de caractères",
          "prefill" => "1",
        },
      }
    end

    context 'when update succeeds' do
      let(:update_params) do
        {
          referentiel_mapping: {
            "$.jsonpath1" => {
              "type" => "Chaine de caractères",
              prefill_stable_id: prefillable_stable_id,
              "prefill" => "1",
            },
          },
        }
      end
      context 'when referentiel is public' do
        it 'updates prefill_stable_id for each mapping element and redirects to prefill_and_display' do
          patch :update_prefill_and_display_type_de_champ, params: {
            procedure_id: procedure.id,
            stable_id: type_de_champ.stable_id,
            id: referentiel.id,
            type_de_champ: update_params,
          }
          expect(response).to redirect_to(champs_admin_procedure_path(procedure))
          expect(flash[:notice]).to eq("La configuration du pré remplissage des champs et/ou affichage des données récupérées a bien été enregistrée")
          updated_mapping = type_de_champ.reload.referentiel_mapping
          expect(updated_mapping.dig('$.jsonpath1', "type")).to eq("Chaine de caractères")
          expect(updated_mapping.dig('$.jsonpath1', "prefill")).to eq("1")
          expect(updated_mapping.dig('$.jsonpath1', "prefill_stable_id")).to eq(prefillable_stable_id.to_s)
        end
      end

      context 'when referentiel is private' do
        let(:types_de_champ_private) do
          [
            { type: :referentiel, stable_id: stable_id, referentiel_mapping: },
            { type: :text, stable_id: prefillable_stable_id },
          ]
        end
        let(:types_de_champ_public) { [] }
        it 'updates prefill_stable_id for each mapping element and redirects to prefill_and_display' do
          patch :update_prefill_and_display_type_de_champ, params: {
            procedure_id: procedure.id,
              stable_id: type_de_champ.stable_id,
              id: referentiel.id,
              type_de_champ: update_params,
          }
          expect(response).to redirect_to(annotations_admin_procedure_path(procedure))
        end
      end
    end

    describe '#autocomplete_configuration' do
      let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }
      let(:referentiel) { create(:api_referentiel, :autocomplete, :with_autocomplete_response, types_de_champ: [type_de_champ]) }

      context 'PATCH autocomplete_configuration' do
        subject do
          patch :update_autocomplete_configuration, params: {
            procedure_id: procedure.id,
            stable_id: type_de_champ.stable_id,
            id: referentiel.id,
            referentiel: {
              datasource: "$.results",
              tiptap_template: { type: "OK" }.to_json,
            },
            commit: 'Enregistrer la configuration',
          }
        end

        it 'updates the autocomplete_configuration (and serialize tiptap template) and redirects' do
          expect { subject }.to change { referentiel.reload.datasource }.to("$.results")
          expect(referentiel.json_template).to eq({ "type" => "OK" })
          expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel))
          expect(flash[:notice]).to eq("La configuration de l’autocomplete a bien été enregistrée")
        end

        context 'when update fails' do
          before { allow_any_instance_of(Referentiel).to receive(:update).and_return(false) }
          it 'redirects to edit with alert' do
            subject
            expect(response).to have_http_status(:success)
          end
        end
      end

      context 'GET autocomplete_configuration' do
        context 'when referentiel not ready' do
          it 'redirects to configuration error' do
            allow_any_instance_of(ReferentielService).to receive(:validate_referentiel).and_return(false)
            get :autocomplete_configuration, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id }
            expect(response).to redirect_to(configuration_error_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel))
          end
        end

        context 'when referentiel is ready' do
          it 'renders successfully and returns the configuration' do
            allow_any_instance_of(ReferentielService).to receive(:validate_referentiel).and_return(true)
            get :autocomplete_configuration, params: { procedure_id: procedure.id, stable_id: type_de_champ.stable_id, id: referentiel.id }
            expect(response).to have_http_status(:success)
          end
        end
      end
    end

    context 'when update fails' do
      let(:update_params) do
        {
          referentiel_mapping: {
            "jsonpath1" => {
              prefill_stable_id: prefillable_stable_id,
            },
          },
        }
      end

      it 'redirects to prefill_and_display with alert' do
        referentiel
        allow_any_instance_of(TypeDeChamp).to receive(:save).and_return(false)

        patch :update_prefill_and_display_type_de_champ, params: {
          procedure_id: procedure.id,
          stable_id: type_de_champ.stable_id,
          id: referentiel.id,
          type_de_champ: update_params,
        }
        expect(response).to redirect_to(prefill_and_display_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel))
        expect(flash[:alert]).to eq("Une erreur est survenue")
      end
    end
  end
end
