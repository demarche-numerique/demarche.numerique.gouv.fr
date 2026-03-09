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
               url: "https://tabular-api.data.gouv.fr/api/resources/796dfff7-cf54-493a-a0a7-ba3c2024c6f3/data/?finess__contains={id}")
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
            expect(response.parsed_body.first["value"]).to eq("0:010002699 (CENTRE MEDICAL REGINA)")
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
                  url: "https://api.apprentissage.beta.gouv.fr/api/certification/v1?identifiant.cfd={id}",
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
            expect(response.parsed_body.first["value"]).to eq("0:DIPLOME NATIONAL / DIPLOME D'ETAT – AGRO-ALIMENTAIRE, ALIMENTATION, CUISINE ")
            expect(response.parsed_body.first["data"]).to be_an_instance_of(String)
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
