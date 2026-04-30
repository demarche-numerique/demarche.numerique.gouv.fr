# frozen_string_literal: true

describe DataSources::ChorusController do
  let(:administrateur) { administrateurs(:default_admin) }

  render_views

  before do
    sign_in(administrateur.user)
  end

  describe 'search_domaine_fonct' do
    let(:mock_api_response) do
      JSON.parse(Rails.root.join("spec/fixtures/files/api_databretagne/domaine-fonct.json").read)['items']
    end

    before do
      allow_any_instance_of(APIBretagneService).to receive(:search_domaine_fonct).and_return(mock_api_response)
    end

    it 'works' do
      get :search_domaine_fonct, params: { q: "Dépenses" }
      expect(response.parsed_body.size).to eq(mock_api_response.size)
    end
  end

  describe 'search_centre_couts' do
    let(:mock_api_response) do
      JSON.parse(Rails.root.join("spec/fixtures/files/api_databretagne/centre-couts.json").read)['items']
    end

    before do
      allow_any_instance_of(APIBretagneService).to receive(:search_centre_couts).and_return(mock_api_response)
    end

    it 'works' do
      get :search_centre_couts, params: { q: "Dépenses" }
      expect(response.parsed_body.size).to eq(mock_api_response.size)
    end

    context 'when API Bretagne login returns 403 (invalid credentials)' do
      before do
        allow_any_instance_of(APIBretagneService).to receive(:search_centre_couts).and_call_original
        allow_any_instance_of(API::Client).to receive(:call)
          .and_return(Dry::Monads::Failure(API::Client::Error[:http, 403, true, "Forbidden"]))
      end

      it 'returns an empty JSON array and logs to Sentry' do
        expect(Sentry).to receive(:capture_message).with("APIBretagneService error", extra: { code: 403, error: "Forbidden" })
        get :search_centre_couts, params: { q: "Dépenses" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
      end
    end
  end

  describe 'search_ref_programmation' do
    let(:mock_api_response) do
      JSON.parse(Rails.root.join("spec/fixtures/files/api_databretagne/ref-programmation.json").read)['items']
    end

    before do
      allow_any_instance_of(APIBretagneService).to receive(:search_ref_programmation).and_return(mock_api_response)
    end

    it 'works' do
      get :search_ref_programmation, params: { q: "Dépenses" }
      expect(response.parsed_body.size).to eq(mock_api_response.size)
    end
  end
end
