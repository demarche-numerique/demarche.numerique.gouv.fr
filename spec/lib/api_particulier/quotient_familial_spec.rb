# frozen_string_literal: true

describe APIParticulier::QuotientFamilial do
  describe '#quotient_familial' do
    let(:procedure) { create(:procedure, :with_api_particulier_token, :with_service) }
    let(:api) { APIParticulier::QuotientFamilial.new(procedure) }
    let(:fci) { create(:france_connect_information) }
    let(:subject) { api.quotient_familial(fci) }

    before do
      stub_request(:get, /https:\/\/particulier.api.gouv.fr\/v3\/dss\/quotient_familial\/identite/)
        .to_return(body: body, status: status)
    end

    context "when success response with valid schema" do
      let(:status) { 200 }
      let(:body) {
        {
          data:
            {
              "adresse": {
                "pays": "FRANCE",
                "lieu_dit": nil,
                "destinataire": "Madame ROUX Jeanne",
                "code_postal_ville": "75002 PARIS",
                "numero_libelle_voie": "1 RUE MONTORGUEIL",
                "complement_information": nil,
                "complement_information_geographique": nil,
              },
              "allocataires": [
                {
                  "sexe": "F",
                  "prenoms": "JEANNE STEPHANIE",
                  "nom_usage": "ROUX",
                  "nom_naissance": "ROUX",
                  "date_naissance": "1987-06-27",
                },
              ],
              "enfants": [],
              "quotient_familial": {
                "valeur": 464,
                "fournisseur": "CAF",
                "annee": 2023,
                "mois": 12,
                "annee_calcul": 2023,
                "mois_calcul": 12,
              },
            },
        }.to_json
      }

      it 'returns a Success' do
        expect(subject).to be_success
      end
    end

    context "when success response with not valid schema" do
      let(:status) { 200 }
      let(:body) {
        {
          data: { quotient_familial: "123" },
        }.to_json
      }

      it 'returns a Failure with an invalid_schema code' do
        expect(subject).to be_failure
        expect(subject.failure).to include(code: :invalid_schema)
      end
    end

    context "when responds with error" do
      let(:status) { 400 }
      let(:body) { { errors: "dossier allocataire non trouvé" }.to_json }

      it 'returns a Failure with an invalid_schema code' do
        expect(subject).to be_failure
        expect(subject.failure[:error].message).to include("dossier allocataire non trouvé")
      end
    end
  end
end
