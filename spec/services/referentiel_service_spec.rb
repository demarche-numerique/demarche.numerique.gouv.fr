# frozen_string_literal: true

RSpec.describe ReferentielService, type: :service do
  let(:api_referentiel) { create(:api_referentiel, :exact_match, url:, test_data:) }
  let(:url) { "https://rnb-api.beta.gouv.fr/api/alpha/buildings/{id}/" }
  let(:test_data) { "PG46YY6YWCX8" }
  let(:stub_api_call) do
    stub_request(:get, api_referentiel.url.gsub('{id}', query_params))
      .to_return(status:, body: body&.to_json)
  end
  before { stub_api_call }

  describe '.validate_referentiel either it works, either it does not' do
    let(:query_params) { api_referentiel.test_data }
    subject { described_class.new(referentiel: api_referentiel).validate_referentiel }

    context 'when referentiel works' do
      let(:status) { 200 }
      let(:body) { { rnb_id: api_referentiel.test_data } }
      it { is_expected.to eq(true) }
      it 'update referentiel.last_response and body with expected data' do
        expect { subject }.to change { api_referentiel.reload.last_response }.from(nil).to({ status:, body: }.with_indifferent_access)
      end
    end

    context 'when response is 201, without content' do
      let(:status) { 201 }
      let(:body) { nil }
      it { is_expected.to eq(false) }
      it 'updates referentiel.last_response with status and body as failure' do
        expect { subject }.to change { api_referentiel.reload.last_response }.from(nil).to({ status:, body: }.with_indifferent_access)
      end
    end

    context 'when response is 201, with content ' do
      let(:status) { 201 }
      let(:body) { "{}" }
      it { is_expected.to eq(true) }
      it 'update referentiel.last_response with status (forced to 200 for now) and body' do
        expect { subject }.to change { api_referentiel.reload.last_response }.from(nil).to({ status: 200, body: }.with_indifferent_access)
      end
    end

    context 'when response is 300' do
      let(:status) { 300 }
      let(:body) { nil }
      it { is_expected.to eq(false) }
      it 'update referentiel.last_response with status and body' do
        expect { subject }.to change { api_referentiel.reload.last_response }.from(nil).to({ status:, body: }.with_indifferent_access)
      end
    end

    context "when referentiel 404 (not found)" do
      let(:status) { 404 }
      let(:body) { nil }

      it "update referentiel.last_response with status and body" do
        expect { subject }.to change { api_referentiel.reload.last_response }.from(nil).to({ status:, body: }.with_indifferent_access)
      end
    end
  end

  describe '.call' do
    include Dry::Monads[:result]

    let(:query_params) { api_referentiel.test_data }
    subject { described_class.new(referentiel: api_referentiel).call(query_params) }

    context "when referentiel 200 success" do
      let(:status) { 200 }
      let(:body) { { body: :ok } }
      it "return a Success" do
        expect(subject).to be_success
      end
    end

    context "when referentiel 404 (not found)" do
      let(:status) { 404 }
      let(:body) { nil }
      it "returns a not retryable Failure" do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: false, error: StandardError.new('Not retryable: 404'), code: 404)
      end
    end

    context "when referentiel 429 (rate limit)" do
      let(:status) { 429 }
      let(:body) { nil }
      it "returns a retryable Failure" do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: true, error: StandardError.new('Retryable: 429'), code: 429)
      end
    end

    context "when referentiel teapots" do
      let(:status) { 418 }
      let(:body) { nil }
      it "returns a retryable Failure" do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: false, error: StandardError.new('Unknown error'), code: 418)
      end
    end

    context 'when referentiel has authentication' do
      let(:api_referentiel) { create(:api_referentiel, :exact_match, url:, test_data:, authentication_method: 'header_token', authentication_data: { header: 'Authorization', value: 'Bearer kthxbye' }) }
      let(:status) { 200 }
      let(:body) { { body: :ok } }
      let(:stub_api_call) do
        stub_request(:get, api_referentiel.url.gsub('{id}', query_params))
          .with(headers: { 'Authorization' => "Bearer kthxbye" })
          .to_return(status:, body: body&.to_json)
      end
      it 'forwards the authentication header' do
        expect(subject).to be_success
        expect(WebMock).to have_requested(:get, api_referentiel.url.gsub('{id}', query_params))
          .with(headers: { 'Authorization' => "Bearer kthxbye" })
      end
    end
  end
end
