# frozen_string_literal: true

RSpec.describe ReferentielService, type: :service do
  let(:api_referentiel) { create(:api_referentiel, :exact_match) }
  let(:query_params) { api_referentiel.effective_test_data }
  let(:resolved_url) { described_class.new(referentiel: api_referentiel).url(query_params) }

  describe '.validate_referentiel either it works, either it does not' do
    subject { described_class.new(referentiel: api_referentiel).validate_referentiel }
    before { stub_request(:get, resolved_url).to_return(status:, body: body&.to_json) }

    context 'when referentiel works' do
      let(:status) { 200 }
      let(:body) { { rnb_id: api_referentiel.effective_test_data } }
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

    subject { described_class.new(referentiel: api_referentiel).call(query_params) }
    before { stub_request(:get, resolved_url).to_return(status:, body: body&.to_json) }

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
      let(:api_referentiel) { create(:api_referentiel, :exact_match, authentication_method: 'header_token', authentication_data: { header: 'Authorization', value: 'Bearer kthxbye' }) }
      let(:status) { 200 }
      let(:body) { { body: :ok } }
      before do
        stub_request(:get, resolved_url)
          .with(headers: { 'Authorization' => "Bearer kthxbye" })
          .to_return(status:, body: body&.to_json)
      end
      it 'forwards the authentication header' do
        expect(subject).to be_success
        expect(WebMock).to have_requested(:get, resolved_url)
          .with(headers: { 'Authorization' => "Bearer kthxbye" })
      end
    end
  end

  describe '#resolve_tiptap_url' do
    let(:api_referentiel) { build(:api_referentiel, :exact_match, url_tiptap:) }
    let(:service) { described_class.new(referentiel: api_referentiel) }

    let(:url_tiptap) do
      {
        "type" => "doc", "content" => [
          {
            "type" => "paragraph", "content" => [
              { "type" => "text", "text" => "https://api.gouv.fr/" },
              { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } },
              { "type" => "text", "text" => "/dep/" },
              { "type" => "mention", "attrs" => { "id" => "tdc42", "label" => "Dep" } },
            ],
          },
        ],
      }
    end

    context 'with Hash values_source and all values present' do
      let(:values_source) { { "{query}" => "search term", "tdc42" => "75" } }
      it 'resolves URL with encoding' do
        result = service.send(:resolve_tiptap_url, "search term", values_source)
        expect(result).to eq("https://api.gouv.fr/search+term/dep/75")
      end
    end

    context 'with Hash values_source and empty tdc value' do
      let(:values_source) { { "{query}" => "search", "tdc42" => "" } }
      it { expect(service.send(:resolve_tiptap_url, "search", values_source)).to be_nil }
    end

    context 'with blank query_params when {query} tag present' do
      let(:values_source) { { "{query}" => "", "tdc42" => "75" } }
      it { expect(service.send(:resolve_tiptap_url, "", values_source)).to be_nil }
    end

    context 'with special characters' do
      let(:values_source) { { "{query}" => "café & thé", "tdc42" => "île de france" } }
      it 'applies URI encoding' do
        result = service.send(:resolve_tiptap_url, "café & thé", values_source)
        expect(result).to include("caf%C3%A9+%26+th%C3%A9")
        expect(result).to include("%C3%AEle+de+france")
      end
    end

    context 'with Dossier as values_source' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:type_de_champ) { procedure.draft_revision.types_de_champ_public.first }
      let(:url_tiptap) do
        {
          "type" => "doc", "content" => [
            {
              "type" => "paragraph", "content" => [
                { "type" => "text", "text" => "https://api.gouv.fr/" },
                { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } },
                { "type" => "text", "text" => "/dep/" },
                { "type" => "mention", "attrs" => { "id" => "tdc#{type_de_champ.stable_id}", "label" => "Dep" } },
              ],
            },
          ],
        }
      end

      before do
        dossier.champs.find { _1.stable_id == type_de_champ.stable_id }.update!(value: "75")
      end

      it 'resolves tdc tags from dossier champs' do
        result = service.send(:resolve_tiptap_url, "search", dossier)
        expect(result).to eq("https://api.gouv.fr/search/dep/75")
      end

      context 'when champ value is blank' do
        before do
          dossier.champs.find { _1.stable_id == type_de_champ.stable_id }.update!(value: "")
        end

        it { expect(service.send(:resolve_tiptap_url, "search", dossier)).to be_nil }
      end
    end

    context 'when url_tiptap is nil' do
      let(:url_tiptap) { nil }
      it { expect(service.send(:resolve_tiptap_url, "q", {})).to be_nil }
    end

    context 'when values_source is nil' do
      it { expect(service.send(:resolve_tiptap_url, "search", nil)).to be_nil }
    end
  end
end
