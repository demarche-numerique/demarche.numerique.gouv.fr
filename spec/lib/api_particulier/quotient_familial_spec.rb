# frozen_string_literal: true

describe APIParticulier::QuotientFamilial do
  describe '#quotient_familial' do
    let(:procedure) { create(:procedure, :with_api_particulier_token, :with_service) }
    let(:api) { APIParticulier::QuotientFamilial.new(procedure) }
    let(:fci) { create(:france_connect_information) }
    let(:subject) { api.quotient_familial(fci) }

    before do
      stub_request(:get, /https:\/\/particulier.api.gouv.fr\/api\/v3\/dss\/quotient_familial\/identite/)
        .to_return(body: body, status: status)
    end

    context "when success response with valid schema" do
      let(:status) { 200 }
      let(:body) {
        {
          data:
            JSON.parse(
              Rails.root.join("app/components/editable_champ/quotient_familial_component/preview_quotient_familial_data.json").read
            ),
        }.to_json
      }

      it 'returns a Success' do
        expect(subject).to be_success
      end
    end

    context "when success response with not valid schema" do
      let(:status) { 200 }
      let(:body) { { quotient_familial: "123" }.to_json }

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
        expect(subject.failure[:reason].message).to include("dossier allocataire non trouvé")
      end
    end
  end
end
