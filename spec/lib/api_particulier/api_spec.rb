# frozen_string_literal: true

describe APIParticulier::API do
  let(:procedure) { create(:procedure, :with_api_particulier_token, :with_service) }
  let(:api) { APIParticulier::API.new(procedure, type_champ) }
  let(:fci) { create(:france_connect_information) }
  let(:subject) { api.call_with_fci(fci) }

  # Le .env local peut pointer sur staging, que le stub WebMock ne reconnaît pas.
  before { stub_const("API_PARTICULIER_URL", "https://particulier.api.gouv.fr") }

  context ' when type_champ is quotient_familial' do
    let(:type_champ) { 'quotient_familial' }

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

    context "when success response with reduced scopes" do
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

      it 'returns a Failure carrying the http code, without the response body' do
        expect(subject).to be_failure
        expect(subject.failure).to include(code: 400)
        expect(subject.failure[:error].message).to eq("API Particulier: 400")
      end
    end

    context "when responds with a business error code" do
      let(:status) { 403 }
      # La réponse de RAILS-MGX.
      let(:body) do
        { errors: [{ code: "00101", title: "Interdit", detail: "Votre token n'est pas valide ou n'est pas renseigné" }] }.to_json
      end

      it 'keeps the business code, not the whole response body' do
        expect(subject.failure[:error].message).to eq("API Particulier: 403 00101")
      end
    end
  end

  describe 'unusable token' do
    let(:type_champ) { 'quotient_familial' }

    context "when the procedure token cannot be decoded" do
      # Le cas de RAILS-MGX : l'administrateur avait saisi n'importe quoi. La
      # validation l'interdit désormais, mais de tels jetons sont déjà en base.
      let(:procedure) do
        create(:procedure, :with_service).tap do
          it.api_particulier_token = 'azertyuiopqsdfgh'
          it.save(validate: false)
        end
      end

      it 'fails without calling API Particulier' do
        expect(subject).to be_failure
        expect(subject.failure).to include(code: :token_unusable)
        expect(WebMock).not_to have_requested(:get, /particulier.api.gouv.fr/)
      end
    end
  end
end
