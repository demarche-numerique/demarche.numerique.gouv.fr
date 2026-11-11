# frozen_string_literal: true

RSpec.describe ReferentielService, type: :service do
  def url_tiptap_for(tag_id, separator = "/dep/")
    {
      "type" => "doc", "content" => [
        {
          "type" => "paragraph", "content" => [
            { "type" => "text", "text" => "https://api.gouv.fr/" },
            { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } },
            { "type" => "text", "text" => separator },
            { "type" => "mention", "attrs" => { "id" => tag_id, "label" => "Tag" } },
          ],
        },
      ],
    }
  end

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

    context "when referentiel 504 (gateway timeout)" do
      let(:status) { 504 }
      let(:body) { nil }
      it "returns a retryable Failure" do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: true, error: StandardError.new('Retryable: 504'), code: 504)
      end
    end

    context "when the request times out or the network fails (no HTTP response)" do
      let(:status) { 200 }
      let(:body) { nil }
      before do
        allow_any_instance_of(API::Client).to receive(:call)
          .and_return(Dry::Monads::Failure(API::Client::Error[:timeout, 0, true, StandardError.new("Timeout")]))
      end

      it "returns a retryable Failure" do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: true, error: StandardError.new('Retryable: timeout'), code: 0)
      end
    end

    context "when referentiel teapots" do
      let(:status) { 418 }
      let(:body) { nil }
      it "returns a non retryable Failure detailing the type and code" do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: false, error: StandardError.new('Unknown error: http (code: 418)'), code: 418)
      end
    end

    context "when referentiel returns 200 with a non-JSON body" do
      let(:status) { 200 }
      let(:body) { nil }
      before { stub_request(:get, resolved_url).to_return(status: 200, body: "<html>oops</html>") }

      it "returns a non retryable Failure detailing the type and code" do
        expect(subject).to be_failure
        expect(subject.failure).to include(retryable: false, error: StandardError.new('Unknown error: json (code: 200)'), code: 200)
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

    let(:url_tiptap) { url_tiptap_for("tdc42") }

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
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:type_de_champ) { procedure.draft_revision.public_root_type_de_champs.first }
      let(:url_tiptap) { url_tiptap_for("tdc#{type_de_champ.stable_id}") }

      before do
        dossier.champ_data.find { _1.stable_id == type_de_champ.stable_id }.update!(value: "75")
      end

      it 'resolves tdc tags from dossier champs' do
        result = service.send(:resolve_tiptap_url, "search", dossier)
        expect(result).to eq("https://api.gouv.fr/search/dep/75")
      end

      context 'when champ value is blank' do
        before do
          dossier.champ_data.find { _1.stable_id == type_de_champ.stable_id }.update!(value: "")
        end

        it { expect(service.send(:resolve_tiptap_url, "search", dossier)).to be_nil }
      end
    end

    context 'with yes_no champ as values_source' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :yes_no }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:type_de_champ) { procedure.draft_revision.public_root_type_de_champs.first }
      let(:url_tiptap) { url_tiptap_for("tdc#{type_de_champ.stable_id}", "?flag=") }

      context 'when value is true' do
        it 'resolves boolean true value' do
          result = service.send(:resolve_tiptap_url, "search", dossier)
          expect(result).to eq("https://api.gouv.fr/search?flag=true")
        end
      end

      context 'when value is false' do
        before do
          dossier.champ_data.find { _1.stable_id == type_de_champ.stable_id }.update!(value: "false")
        end

        it 'resolves boolean false value' do
          result = service.send(:resolve_tiptap_url, "search", dossier)
          expect(result).to eq("https://api.gouv.fr/search?flag=false")
        end
      end
    end

    context 'with address champ as values_source' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :address }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:type_de_champ) { procedure.draft_revision.public_root_type_de_champs.first }
      let(:url_tiptap) { url_tiptap_for("tdc#{type_de_champ.stable_id}", "?address=") }

      it 'resolves address label with encoding' do
        result = service.send(:resolve_tiptap_url, "search", dossier)
        expect(result).to eq("https://api.gouv.fr/search?address=2+rue+des+D%C3%A9marches")
      end
    end

    context 'when the document holds more than the validated block' do
      let(:url_tiptap) do
        url_tiptap_for("tdc42").tap do |document|
          document["content"].first["type"] = "heading"
          document["content"] << { "type" => "paragraph", "content" => [{ "type" => "text", "text" => "https://example.com/" }] }
        end
      end

      it 'resolves the validated block only' do
        result = service.send(:resolve_tiptap_url, "search", { "tdc42" => "75" })
        expect(result).to eq("https://api.gouv.fr/search/dep/75")
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

  describe '#url with a row_id' do
    let(:api_referentiel) { build(:api_referentiel, :exact_match, url_tiptap:) }
    let(:service) { described_class.new(referentiel: api_referentiel) }
    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { type: :text, stable_id: 1, libelle: 'Code' },
        {
          type: :repetition, stable_id: 100, libelle: 'Bloc', children: [
            { type: :text, stable_id: 102, libelle: 'Code' },
          ],
        },
      ])
    end
    let(:dossier) { create(:dossier, procedure:) }
    let(:repetition) { dossier.find_type_de_champ_by_stable_id(100) }
    let(:type_de_champ) { dossier.find_type_de_champ_by_stable_id(102) }
    let(:row_ids) do
      Array.new(2) { dossier.repetition_add_row(repetition, updated_by: 'test') }
    end

    before do
      row_ids.each_with_index do |row_id, index|
        dossier.champ_for_update(type_de_champ, row_id:, updated_by: 'test').update!(value: "LIGNE-#{index + 1}")
      end
      dossier.champ_data.find { _1.stable_id == 1 }.update!(value: "RACINE")
      dossier.reload
    end

    context 'when the tag targets a champ of the repetition' do
      let(:url_tiptap) { url_tiptap_for("tdc102", "/code/") }

      it 'resolves the champ of the given row' do
        expect(service.url("search", dossier:, row_id: row_ids.first)).to eq("https://api.gouv.fr/search/code/LIGNE-1")
        expect(service.url("search", dossier:, row_id: row_ids.second)).to eq("https://api.gouv.fr/search/code/LIGNE-2")
      end
    end

    context 'when the tag targets a champ outside of the repetition' do
      let(:url_tiptap) { url_tiptap_for("tdc1", "/code/") }

      it 'resolves the root champ whatever the row' do
        expect(service.url("search", dossier:, row_id: row_ids.second)).to eq("https://api.gouv.fr/search/code/RACINE")
      end
    end

    context 'when the champ of the given row is not filled yet' do
      let(:url_tiptap) { url_tiptap_for("tdc102", "/code/") }
      let(:empty_row_id) { dossier.repetition_add_row(repetition, updated_by: 'test') }

      it 'does not resolve the url rather than borrowing another row' do
        expect(service.url("search", dossier: dossier.reload, row_id: empty_row_id)).to be_nil
      end
    end

    context 'when the referentiel champ is outside of the repetition (no row context)' do
      let(:url_tiptap) { url_tiptap_for("tdc102", "/code/") }

      it 'resolves the first row' do
        expect(service.url("search", dossier:)).to eq("https://api.gouv.fr/search/code/LIGNE-1")
      end
    end
  end

  describe '#url with the {dossier_number} tag' do
    let(:url_tiptap) { url_tiptap_for(described_class::DOSSIER_NUMBER_TAG, "/dossier/") }
    let(:test_data_tiptap) { { "{query}" => "search", described_class::DOSSIER_NUMBER_TAG => "1234" } }
    let(:api_referentiel) { build(:api_referentiel, :exact_match, url_tiptap:, test_data_tiptap:) }
    let(:service) { described_class.new(referentiel: api_referentiel) }

    context 'with a dossier' do
      let(:dossier) { dossiers.en_construction }

      it 'resolves the tag to the dossier id' do
        expect(service.url("search", dossier:)).to eq("https://api.gouv.fr/search/dossier/#{dossier.id}")
      end
    end

    context 'without a dossier, from the admin test screen' do
      it 'falls back on the admin test data' do
        expect(service.test_url).to eq("https://api.gouv.fr/search/dossier/1234")
      end
    end

    context 'without a dossier and without test data for the tag' do
      let(:test_data_tiptap) { { "{query}" => "search" } }

      it { expect(service.test_url).to be_nil }
    end
  end
end
