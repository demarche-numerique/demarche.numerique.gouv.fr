# frozen_string_literal: true

describe OCRService do
  include Dry::Monads[:result]

  describe '#analyze rib' do
    context 'when the service is enabled' do
      let(:ocr_service_url) { 'http://an_ocr_service/analyze' }
      let(:blob_url) { 'http://example.com/blob.pdf' }
      let(:blob) { double('Blob', url: blob_url) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("OCR_SERVICE_URL", nil)
          .and_return(ocr_service_url)
      end

      context 'when the OCR service responds successfully' do
        let(:body) do
          {
            "2ddoc": nil,
            "rib": {
              "account_holder": "Mme Titulaire\n58 BD ROBERT\n13284 MARSEILLE CEDEX 07",
              "iban": "FR76 6666 6666 6666 6666 6666 780",
              "bic": "BICUFRP1",
            },
          }
        end

        before do
          stub_request(:post, ocr_service_url)
            .with(body: { url: blob_url, hint: { type: 'rib' } })
            .to_return(body: body.to_json, status: 200)
        end

        it 'returns a success with the correct value_json' do
          analysis = described_class.analyze(blob, nature: 'rib')
          expect(analysis).to eq(Success(value_json: body))
        end
      end

      context 'when the OCR service responds with an error' do
        before do
          stub_request(:post, ocr_service_url)
            .with(body: { url: blob_url, hint: { type: 'rib' } })
            .to_return(status: 422, body: { error: 'Invalid request' }.to_json)
        end

        it 'handles the error gracefully' do
          analysis = described_class.analyze(blob, nature: 'rib')
          expect(analysis.failure?).to be true
          expect(analysis.failure[:code]).to eq(422)
          expect(analysis.failure[:error].to_s).to include('Invalid')
        end
      end
    end
  end

  describe '#analyze with unknown nature' do
    let(:blob) { double('Blob', url: 'http://example.com/blob.pdf') }

    it 'raises ArgumentError' do
      expect { described_class.analyze(blob, nature: 'UNKNOWN') }
        .to raise_error(ArgumentError, /unknown nature/)
    end
  end

  describe '#analyze_2ddoc' do
    let(:document_ia_url) { 'https://some_url.fr' }
    let(:document_ia_key) { 'some_key' }
    let(:blob_url) { 'http://example.com/blob.pdf' }
    let(:blob) { double('Blob', url: blob_url) }
    let(:headers) { { 'X-API-KEY': document_ia_key } }
    let(:url) { "#{document_ia_url}/api/v1/workflows/document-barcode-extraction/execute-sync" }
    let(:body) { File.read('spec/fixtures/files/doc_ia/success.json') }
    let(:ban_query) { '123 RUE DES PIETONS 38000 GRENOBLE' }
    let(:ban_body) do
      {
        features: [{
          type: 'Feature',
          geometry: { type: 'Point', coordinates: [5.7245, 45.1885] },
          properties: {
            label: '123 Rue des Piétons 38000 Grenoble',
            name: '123 Rue des Piétons',
            housenumber: '123',
            street: 'Rue des Piétons',
            postcode: '38000',
            citycode: '38185',
            city: 'Grenoble',
            context: '38, Isère, Auvergne-Rhône-Alpes',
            type: 'housenumber'
          }
        }]
      }.to_json
    end

    subject { described_class.analyze(blob, nature: 'justificatif_domicile') }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DOCUMENT_IA_URL", nil)
        .and_return(document_ia_url)
      allow(ENV).to receive(:fetch).with("DOCUMENT_IA_KEY")
        .and_return(document_ia_key)

      stub_request(:post, url).with(headers:, body: { file_url: blob.url })
        .to_return(body:, status: 200)
      stub_request(:get, "#{API_ADRESSE_URL}/search")
        .with(query: { q: ban_query, limit: 1 })
        .to_return(body: ban_body, status: 200)
    end

    context 'when there is no document ia url' do
      let(:document_ia_url) { nil }

      it { is_expected.to be_failure }
    end

    context 'when the result is ok' do
      it 'returns a BAN-normalized address merged with 2ddoc fields' do
        value_json = subject.value![:value_json]

        expect(value_json).to include(
          "label" => '123 Rue des Piétons 38000 Grenoble',
          "street_address" => '123 Rue des Piétons',
          "postal_code" => '38000',
          "city_code" => '38185',
          "city_name" => 'Grenoble',
          "department_code" => '38',
          "department_name" => 'Isère',
          "region_code" => '84',
          "region_name" => 'Auvergne-Rhône-Alpes',
          "country_code" => 'FR',
          "beneficiary" => 'ROBERT JEAN',
          "issue_date" => Date.parse('2026-01-02'),
          "two_ddoc" => true
        )
      end
    end

    context 'when BAN returns no feature' do
      let(:ban_body) { { features: [] }.to_json }

      it 'returns nil value_json (raw data kept for replay)' do
        expect(subject.value![:value_json]).to be_nil
        expect(subject.value![:data]).not_to be_nil
      end
    end

    context 'when the result is ko' do
      let(:body) { File.read('spec/fixtures/files/doc_ia/failed.json') }

      it do
        expect(subject.value![:value_json]).to be_nil
        expect(subject.value![:data]).not_to be_nil
      end
    end
  end
end
