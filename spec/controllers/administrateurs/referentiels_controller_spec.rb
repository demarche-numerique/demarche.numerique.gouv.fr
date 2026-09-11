# frozen_string_literal: true

describe Administrateurs::ReferentielsController, type: :controller do
  let(:stable_id) { 123 }
  let(:public_type_de_champs) { [{ type: :referentiel, stable_id: }] }
  let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs:) }
  let(:private_type_de_champs) { [] }

  before { sign_in(procedure.administrateurs.first.user) }

  describe 'IDOR on retrieve_referentiel (edit/update)' do
    let(:other_referentiel) { create(:api_referentiel, :exact_match, :with_authentication_data) }
    let(:other_procedure) { create(:procedure, public_type_de_champs: [{ type: :referentiel, referentiel: other_referentiel }]) }
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

  describe '#new' do
    it 'renders successifully' do
      get :new, params: { procedure_id: procedure.id, stable_id: }
      expect(response).to have_http_status(:success)
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

        expect(referentiel.type_de_champs).to include(TypeDeChamp.find_by(stable_id:))
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

          expect(referentiel.type_de_champs).to include(TypeDeChamp.find_by(stable_id:))
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

          expect(referentiel.type_de_champs).to include(TypeDeChamp.find_by(stable_id:))
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

  describe 'writing to a referentiel shared with the published revision' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:published_type_de_champ) { procedure.published_revision.type_de_champs.find { it.stable_id == stable_id } }
    let!(:referentiel) { create(:api_referentiel, :exact_match, hint: 'avant', type_de_champs: [published_type_de_champ]) }
    let(:draft_type_de_champ) { procedure.draft_revision.type_de_champs.find { it.stable_id == stable_id } }

    describe '#update' do
      subject do
        patch :update, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id, referentiel: { hint: 'après' } }, format: :turbo_stream
      end

      it 'applies the change to a copy and leaves the published revision on the original' do
        expect { subject }.to change { Referentiel.count }.by(1)

        expect(referentiel.reload.hint).to eq('avant')
        expect(published_type_de_champ.reload.referentiel).to eq(referentiel)
        expect(draft_type_de_champ.referentiel).not_to eq(referentiel)
        expect(draft_type_de_champ.referentiel.hint).to eq('après')
      end
    end

    describe '#update_autocomplete_configuration' do
      let!(:referentiel) { create(:api_referentiel, :autocomplete, :with_autocomplete_response, type_de_champs: [published_type_de_champ]) }

      subject do
        patch :update_autocomplete_configuration, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id, commit: 'Étape suivante', referentiel: { datasource: '$.', tiptap_template: '{}' } }
      end

      it 'applies the change to a copy and redirects to the mapping of that copy' do
        expect { subject }.to change { Referentiel.count }.by(1)

        expect(referentiel.reload.datasource).to be_nil
        expect(draft_type_de_champ.referentiel.datasource).to eq('$.')
        expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, stable_id, draft_type_de_champ.referentiel))
      end
    end

    describe '#update_mapping_type_de_champ' do
      subject do
        patch :update_mapping_type_de_champ, params: {
          procedure_id: procedure.id,
          stable_id:,
          id: referentiel.id,
          type_de_champ: { referentiel_mapping: { "$.records{0}.id" => { type: "string" }, "$.records{0}.fields.Nom" => { type: "string" } } },
        }
      end

      it 'writes the result path on a copy and leaves the published revision on the original' do
        expect { subject }.to change { Referentiel.count }.by(1)

        expect(referentiel.reload.result_path).to be_nil
        expect(published_type_de_champ.reload.referentiel).to eq(referentiel)
        expect(draft_type_de_champ.referentiel).not_to eq(referentiel)
        expect(draft_type_de_champ.referentiel.result_path).to eq("$.records[0]")
        expect(response).to redirect_to(prefill_and_display_admin_procedure_referentiel_path(procedure, stable_id, draft_type_de_champ.referentiel))
      end
    end

    describe '#reset_mapping' do
      subject do
        delete :reset_mapping, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id, scope: 'all' }
      end

      it 'redirects to the mapping of the copy rather than back to the original' do
        expect { subject }.to change { Referentiel.count }.by(1)

        expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, stable_id, draft_type_de_champ.referentiel))
      end
    end
  end

  describe "#edit" do
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }
    let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }

    it 'works' do
      get :edit, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "#update" do
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }
    let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }

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
          type_de_champs: [type_de_champ],
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

      it 'updates the referentiel and redirects without clearing mapping' do
        subject

        expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, stable_id, referentiel))

        referentiel.reload
        expect(referentiel.mode).to eq(referentiel_params[:mode])
        expect(referentiel.url_tiptap).to eq(new_url_tiptap)
        expect(referentiel.hint).to eq(referentiel_params[:hint])
        expect(referentiel.test_data_tiptap).to eq({ "{query}" => "PG46YY6YWCX8" })

        expect(type_de_champ.reload.referentiel_mapping).to eq({ "old" => { "type" => "string" } })
      end
    end
  end

  describe '#update with tiptap' do
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }
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
      create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ],
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

    context 'full update with url_tiptap change preserves mapping' do
      let(:new_url_tiptap) do
        { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "https://api.gouv.fr/new/" }, { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } }] }] }
      end
      let(:referentiel) do
        create(:api_referentiel, :exact_match, :with_exact_match_response, type_de_champs: [type_de_champ],
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

      it 'updates tiptap data without clearing mapping' do
        subject
        referentiel.reload

        expect(referentiel.url_tiptap).to eq(new_url_tiptap)
        expect(referentiel.test_data_tiptap).to eq({ "{query}" => "new_value" })
        expect(referentiel.hint).to eq('New hint')

        expect(type_de_champ.reload.referentiel_mapping).to eq({ "old" => { "type" => "string" } })

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
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }
    let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }

    it 'works' do
      allow_any_instance_of(Referentiels::APIReferentiel).to receive(:save).and_return(false)
      get :configuration_error, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe '#mapping_type_de_champ' do
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }

    context 'when referentiel not ready' do
      let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }

      it 'redirects to configuration error' do
        allow_any_instance_of(ReferentielService).to receive(:validate_referentiel).and_return(false)
        get :mapping_type_de_champ, params: { procedure_id: procedure.id, stable_id:, id: referentiel.id }
        expect(response).to redirect_to(configuration_error_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel))
      end
    end

    context "when referentiel is ready" do
      let(:referentiel) { create(:api_referentiel, :exact_match, :with_exact_match_response, type_de_champs: [type_de_champ]) }

      before do
        allow_any_instance_of(API::Client)
          .to receive(:call).with(anything).and_return(stub_response)
      end

      context 'test APIReferentiel return valid response' do
        let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }
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
    let(:public_type_de_champs) { [{ type: :referentiel, stable_id:, referentiel_mapping: initial_mapping }] }
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.find { _1.stable_id == stable_id } }
    let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }
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

    context 'when the mapping targets the first element of a collection' do
      let(:initial_mapping) { {} }
      let(:payload_referentiel_mapping) do
        {
          "$.records{0}.id" => { type: "integer_number" },
          "$.records{0}.fields.Nom" => { type: "string" },
        }
      end

      it 'stores the common prefix of the mapped paths as the result path of the referentiel' do
        expect { subject }
          .to change { referentiel.reload.result_path }
          .from(nil)
          .to("$.records[0]")
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
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }
    let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }

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
    let(:public_type_de_champs) do
      [
        { type: :referentiel, stable_id: stable_id, referentiel_mapping: },
        { type: :text, stable_id: prefillable_stable_id },
      ]
    end
    let(:private_type_de_champs) { [] }

    let(:stable_id) { 1 }
    let(:prefillable_stable_id) { 2 }

    let(:type_de_champ) { procedure.draft_revision.type_de_champs.find(&:referentiel?) }
    let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }

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
        let(:private_type_de_champs) do
          [
            { type: :referentiel, stable_id: stable_id, referentiel_mapping: },
            { type: :text, stable_id: prefillable_stable_id },
          ]
        end
        let(:public_type_de_champs) { [] }
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
      let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }
      let(:referentiel) { create(:api_referentiel, :autocomplete, :with_autocomplete_response, type_de_champs: [type_de_champ]) }

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

  describe '#reset_mapping' do
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.find(&:referentiel?) }
    let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }

    let(:referentiel_mapping) do
      {
        "$.name" => { "type" => "string", "libelle" => "Nom", "display_instructeur" => "1", "display_usager" => "1" },
        "$.code" => { "type" => "string", "prefill" => "1", "prefill_stable_id" => "42" },
      }
    end

    before { type_de_champ.update!(referentiel_mapping:) }

    subject { delete :reset_mapping, params: { procedure_id: procedure.id, stable_id: type_de_champ.stable_id, id: referentiel.id, scope: } }

    context 'scope=all' do
      let(:scope) { 'all' }

      before { referentiel.update!(result_path: "$.records[0]") }

      it 'clears the entire mapping and resets the result path to the root' do
        subject
        expect(type_de_champ.reload.referentiel_mapping).to eq({})
        expect(referentiel.reload.result_path).to eq("$")
        expect(flash[:notice]).to eq("La configuration a bien été réinitialisée")
        expect(response).to redirect_to(mapping_type_de_champ_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel))
      end
    end

    context 'scope=display' do
      let(:scope) { 'display' }

      it 'removes display flags but preserves prefill config' do
        subject
        mapping = type_de_champ.reload.referentiel_mapping
        expect(mapping["$.name"]).to eq({ "type" => "string", "libelle" => "Nom" })
        expect(mapping["$.code"]).to eq({ "type" => "string", "prefill" => "1", "prefill_stable_id" => "42" })
        expect(response).to redirect_to(prefill_and_display_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel))
      end
    end

    context 'scope=prefill' do
      let(:scope) { 'prefill' }

      it 'removes prefill config but preserves display flags' do
        subject
        mapping = type_de_champ.reload.referentiel_mapping
        expect(mapping["$.name"]).to eq({ "type" => "string", "libelle" => "Nom", "display_instructeur" => "1", "display_usager" => "1" })
        expect(mapping["$.code"]).to eq({ "type" => "string" })
      end
    end

    context 'scope=invalid' do
      let(:scope) { 'invalid' }

      it 'raises BadRequest' do
        expect { subject }.to raise_error(ActionController::BadRequest)
      end
    end
  end
end
