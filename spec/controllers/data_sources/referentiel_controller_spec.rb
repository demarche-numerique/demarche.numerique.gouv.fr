# frozen_string_literal: true

require 'rails_helper'

describe DataSources::ReferentielController, type: :controller do
  include Dry::Monads[:result]
  describe 'GET #search' do
      let(:user) { create(:user) }
      let(:procedure) { create(:procedure, public_type_de_champs:) }
      let(:dossier) { create(:dossier, procedure:, user:) }
      let(:public_type_de_champs) { [{ type: :referentiel, referentiel: }] }
      let(:referentiel) do
        create(:api_referentiel,
               :autocomplete,
               :with_autocomplete_response,
               datasource: '$.data',
               url_tiptap: {
                 "type" => "doc",
                 "content" => [
                   {
                     "type" => "paragraph",
                     "content" => [
                       { "type" => "text", "text" => "https://tabular-api.data.gouv.fr/api/resources/796dfff7-cf54-493a-a0a7-ba3c2024c6f3/data/?finess__contains=" },
                       { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Valeur saisie par l'usager" } },
                     ],
                   },
                 ],
               },
               test_data_tiptap: { "{query}" => "010002699" })
      end
      before { sign_in(user) }
      subject { post :search, params: { q: '010002699', referentiel_id: referentiel.id, dossier_id: dossier.id } }

      context 'when success params' do
        context 'when referentiel/datagouv-finess' do
          it 'returns formatted results', vcr: 'referentiel/datagouv-finess' do
            expect(subject).to have_http_status(:ok)
            expect(response.parsed_body).to be_an(Array)
            expect(response.parsed_body.size).to eq(1)
            expect(response.parsed_body.first["label"]).to eq("010002699 (CENTRE MEDICAL REGINA)")
            expect(response.parsed_body.first["value"]).to eq("010002699 (CENTRE MEDICAL REGINA)")
            expect(response.parsed_body.first["id"]).to be_a(String)
            expect(response.parsed_body.first["data"]).to be_an_instance_of(String)
          end
        end

        context 'when referentiel/api.apprentissage.beta.gouv.fr' do
          subject { post :search, params: { q: '50022137', referentiel_id: referentiel.id, dossier_id: dossier.id } }
          let(:referentiel) do
            create(:api_referentiel,
                  :autocomplete,
                  :with_autocomplete_response,
                  datasource: '$.',
                  json_template: {
                    "type" => "doc",
                      "content" => [
                        {
                          "type" => "paragraph",
                          "content" => [
                            { "type" => "mention", "attrs" => { "id" => "$.type.nature.cfd.libelle", "label" => "$.type.nature.cfd.libelle (DIPLOME NATIONAL / DIPLOME D'ETAT)" } },
                            { "text" => " – ", "type" => "text" },
                            { "type" => "mention", "attrs" => { "id" => "$.domaines.nsf.cfd.intitule", "label" => "$.domaines.nsf.cfd.intitule (AGRO-ALIMENTAIRE, ALIMENTATION, CUISINE)" } },
                            { "text" => " ", "type" => "text" },
                          ],
                        },
                      ],
                  },
                  url_tiptap: {
                    "type" => "doc",
                    "content" => [
                      {
                        "type" => "paragraph",
                        "content" => [
                          { "type" => "text", "text" => "https://api.apprentissage.beta.gouv.fr/api/certification/v1?identifiant.cfd=" },
                          { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Valeur saisie par l'usager" } },
                        ],
                      },
                    ],
                  },
                  test_data_tiptap: { "{query}" => "50022137" },
                  authentication_method: 'header_token',
                  authentication_data: {
                    header: "Authorization",
                    value: "Bearer kthxbye",
                  })
          end

          it 'returns formatted results', vcr: 'referentiel/api.apprentissage.beta.gouv.fr' do
            expect(subject).to have_http_status(:ok)
            expect(response.parsed_body).to be_an(Array)
            expect(response.parsed_body.size).to eq(4)
            expect(response.parsed_body.first["label"]).to eq("DIPLOME NATIONAL / DIPLOME D'ETAT – AGRO-ALIMENTAIRE, ALIMENTATION, CUISINE ")
            expect(response.parsed_body.first["value"]).to eq("DIPLOME NATIONAL / DIPLOME D'ETAT – AGRO-ALIMENTAIRE, ALIMENTATION, CUISINE ")
            expect(response.parsed_body.first["id"]).to be_a(String)
            expect(response.parsed_body.first["data"]).to be_an_instance_of(String)
          end
        end
      end

      context 'with dossier_id' do
        let(:dossier) { create(:dossier, procedure:, user:) }

        subject { post :search, params: { q: '010002699', referentiel_id: referentiel.id, dossier_id: dossier.id } }

        it 'passes dossier to the service', vcr: 'referentiel/datagouv-finess' do
          expect(subject).to have_http_status(:ok)
        end

        context 'when signed in as instructeur (annotation privée)' do
          let(:instructeur) { create(:instructeur) }
          let(:procedure) { create(:procedure, public_type_de_champs:, instructeurs: [instructeur]) }
          let(:dossier) { create(:dossier, :en_construction, procedure:) }

          before { sign_in(instructeur.user) }

          it 'finds the dossier and returns results', vcr: 'referentiel/datagouv-finess' do
            post :search, params: { q: '010002699', referentiel_id: referentiel.id, dossier_id: dossier.id }
            expect(response).to have_http_status(:ok)
            expect(response.parsed_body).to be_an(Array)
            expect(response.parsed_body.size).to eq(1)
          end
        end

        context 'when the procedure requires FranceConnect+' do
          let(:procedure) { create(:procedure, :published, public_type_de_champs:, france_connect_plus_required: true) }
          let(:service) { instance_double(ReferentielService) }

          before { allow(ReferentielService).to receive(:new).and_return(service) }

          it 'lends no champ value to a session opened another way' do
            sign_in(user, login_method: :password)

            expect(service).not_to receive(:call)
            expect(subject).to have_http_status(:ok)
            expect(response.parsed_body).to eq([])
          end

          it 'searches from a FranceConnect+ session' do
            sign_in(user, login_method: :france_connect_plus)

            expect(service).to receive(:call).and_return(Failure(code: 500))
            expect(subject).to have_http_status(:ok)
          end
        end

        context 'when dossier belongs to another user' do
          let(:other_user) { create(:user) }
          let(:dossier) { create(:dossier, procedure:, user: other_user) }

          it 'returns empty array (dossier not found for current user)' do
            expect(subject).to have_http_status(:ok)
            expect(response.parsed_body).to eq([])
          end
        end
      end

      context "when current_user has no link to the referentiel's procedure" do
        let(:owner_administrateur) { create(:administrateur) }
        let!(:owned_procedure) do
          create(:procedure,
                 administrateurs: [owner_administrateur],
                 public_type_de_champs: [{ type: :referentiel, referentiel: }])
        end
        let(:referentiel) do
          create(:api_referentiel,
                 :autocomplete,
                 :with_autocomplete_response,
                 :with_authentication_data,
                 datasource: '$.data',
                 test_data_tiptap: { "{query}" => "010002699" })
        end
        let(:unrelated_user) { create(:user) }

        before { sign_in(unrelated_user) }

        subject(:cross_tenant_request) do
          post :search, params: { q: '010002699', referentiel_id: referentiel.id }
        end

        it 'does not invoke the outbound referentiel service' do
          expect_any_instance_of(ReferentielService).not_to receive(:call)
          cross_tenant_request
          expect(response.parsed_body).to eq([])
        end

        context 'when a dossier_id of the unrelated user is provided' do
          let(:other_procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]) }
          let(:unrelated_dossier) { create(:dossier, procedure: other_procedure, user: unrelated_user) }

          subject(:cross_tenant_request) do
            post :search, params: { q: '010002699', referentiel_id: referentiel.id, dossier_id: unrelated_dossier.id }
          end

          it 'does not invoke the outbound referentiel service' do
            expect_any_instance_of(ReferentielService).not_to receive(:call)
            cross_tenant_request
            expect(response.parsed_body).to eq([])
          end
        end
      end

      context 'when the dossier is a preview of the draft revision of a published procedure' do
        let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
        let(:draft_referentiel) { referentiel.dup.tap(&:save!) }
        let(:dossier) { procedure.draft_revision.dossier_for_preview(user) }

        before do
          stable_id = procedure.draft_revision.type_de_champs.first.stable_id
          procedure.draft_revision
            .find_and_ensure_exclusive_use(stable_id)
            .update!(referentiel: draft_referentiel)
        end

        subject { post :search, params: { q: '010002699', referentiel_id: draft_referentiel.id, dossier_id: dossier.id } }

        it 'returns results', vcr: 'referentiel/datagouv-finess' do
          expect(subject).to have_http_status(:ok)
          expect(response.parsed_body.size).to eq(1)
        end
      end

      context 'when the referentiel has no rendering template' do
        before { referentiel.update_column(:autocomplete_configuration, { 'datasource' => '$.data' }) }

        it 'returns an empty array without calling the API' do
          expect_any_instance_of(ReferentielService).not_to receive(:call)
          expect(subject).to have_http_status(:ok)
          expect(response.parsed_body).to eq([])
        end
      end

      context 'when a row_id is provided (referentiel champ inside a repetition)' do
        let(:referentiel_service) { instance_double(ReferentielService) }
        subject { post :search, params: { q: '010002699', referentiel_id: referentiel.id, dossier_id: dossier.id, row_id: 'ROW-1' } }

        before { allow(ReferentielService).to receive(:new).and_return(referentiel_service) }

        it 'forwards the row_id, so tags resolve the champs of this row' do
          expect(referentiel_service).to receive(:call).with('010002699', dossier:, row_id: 'ROW-1').and_return(Success({ 'data' => [] }))

          expect(subject).to have_http_status(:ok)
        end

        context 'when the usager is editing a dossier en construction' do
          let(:dossier) { create(:dossier, :en_construction, procedure:, user:) }

          it 'resolves the tags on the stream being edited, where the row being filled lives' do
            expect(referentiel_service).to receive(:call) do |_query, dossier:, row_id:|
              expect(dossier).to be_user_buffer_stream
              expect(row_id).to eq('ROW-1')
              Success({ 'data' => [] })
            end

            expect(subject).to have_http_status(:ok)
          end
        end
      end

      context 'when the referentiel belongs to a private annotation' do
        let(:procedure) { create(:procedure, instructeurs: [instructeurs.default], private_type_de_champs: [{ type: :referentiel, referentiel: }]) }
        let(:dossier) { create(:dossier, :en_construction, procedure:, user:) }

        it 'returns an empty array to the usager without calling the API' do
          expect_any_instance_of(ReferentielService).not_to receive(:call)
          expect(subject.parsed_body).to eq([])
        end

        context 'when signed in as the instructeur of the dossier' do
          before { sign_in(instructeurs.default.user) }

          it 'returns results', vcr: 'referentiel/datagouv-finess' do
            expect(subject.parsed_body.size).to eq(1)
          end
        end

        context "when the dossier is the administrateur's preview of the procedure" do
          let(:dossier) { procedure.draft_revision.dossier_for_preview(user) }

          it 'returns results', vcr: 'referentiel/datagouv-finess' do
            expect(subject.parsed_body.size).to eq(1)
          end
        end
      end

      context 'when failure' do
        let(:referentiel_service) { double(call: service_respone) }

        before do
          expect(ReferentielService).to receive(:new).with(referentiel:, timeout: ReferentielService::API_TIMEOUT / 2).and_return(referentiel_service)
        end

        context 'when service fails' do
          let(:service_respone) { Failure(code: 404) }

          it 'returns an empty array and logs the error' do
            expect(subject).to have_http_status(:ok)
            expect(response.parsed_body).to eq([])
          end
        end

        context 'when service fails with retryable error' do
          let(:service_respone) { Failure(retryable: true, code: 503) }
          let(:retryable_failure) { service_respone }
          let(:success_response) { Success(body: { 'result' => 'ok' }) }

          it 'retries and succeeds' do
            expect(referentiel_service).to receive(:call).and_return(retryable_failure, success_response)
            expect(subject).to have_http_status(:ok)
            expect(response.parsed_body).to eq([])
          end

          it 'retries and fails' do
            expect(referentiel_service).to receive(:call).twice.and_return(retryable_failure, retryable_failure)
            expect(subject).to have_http_status(:ok)
            expect(response.parsed_body).to eq([])
          end
        end

        context 'when service fails with non-retryable error' do
          let(:service_respone) { Failure(retryable: false, code: 404) }

          it 'does not retry and logs the error' do
            expect(referentiel_service).to receive(:call).once.and_return(service_respone)
            expect(subject).to have_http_status(:ok)
            expect(response.parsed_body).to eq([])
          end
        end
      end
    end
end
