# frozen_string_literal: true

require 'rails_helper'

describe DataSources::ReferentielController, type: :controller do
  include Dry::Monads[:result]
  describe 'GET #search' do
      let(:user) { create(:user) }
      let(:procedure) { create(:procedure, types_de_champ_public:) }
      let(:types_de_champ_public) { [{ type: :referentiel, referentiel: }] }
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
      subject { post :search, params: { q: '010002699', referentiel_id: referentiel.id } }

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
          subject { post :search, params: { q: '50022137', referentiel_id: referentiel.id } }
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
          let(:procedure) { create(:procedure, types_de_champ_public:, instructeurs: [instructeur]) }
          let(:dossier) { create(:dossier, :en_construction, procedure:) }

          before { sign_in(instructeur.user) }

          it 'finds the dossier and returns results', vcr: 'referentiel/datagouv-finess' do
            post :search, params: { q: '010002699', referentiel_id: referentiel.id, dossier_id: dossier.id }
            expect(response).to have_http_status(:ok)
            expect(response.parsed_body).to be_an(Array)
            expect(response.parsed_body.size).to eq(1)
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
