# frozen_string_literal: true

describe APIGeoService do
  describe 'pays' do
    it 'countrie_code', :slow do
      countries = JSON.parse(Rails.root.join('spec/fixtures/files/pays_dump.json').read)
      countries_without_code = countries.map { APIGeoService.country_code(_1) }.count(&:nil?)
      expect(countries_without_code).to eq(78)
    end

    describe 'country_name' do
      it 'Kosovo' do
        expect(APIGeoService.country_code('Kosovo')).to eq('XK')
        expect(APIGeoService.country_name('XK')).to eq('Kosovo')
      end

      it 'Thaïlande' do
        expect(APIGeoService.country_code('Thaïlande')).to eq('TH')
        expect(APIGeoService.country_name('TH')).to eq('Thaïlande')
      end
    end
  end

  describe 'regions' do
    it 'return sorted results' do
      expect(APIGeoService.regions.size).to eq(19)
      expect(APIGeoService.regions.first).to eq(code: '84', name: 'Auvergne-Rhône-Alpes')
      expect(APIGeoService.regions.last).to eq(code: '99', name: 'Etranger')
    end
  end

  describe 'departements' do
    it 'return sorted results' do
      expect(APIGeoService.departements.size).to eq(110)
      expect(APIGeoService.departements.first).to eq(code: '01', name: 'Ain', region_code: "84")
      expect(APIGeoService.departements.last).to eq(code: '99', name: 'Etranger')
    end
  end

  describe 'communes' do
    it 'return sorted results' do
      expect(APIGeoService.communes('01').size).to eq(397)
      expect(APIGeoService.communes('01').first).to eq(code: '01004', name: 'Ambérieu-en-Bugey', postal_code: '01500', departement_code: '01', epci_code: '240100883', region_code: "84")
      expect(APIGeoService.communes('01').last).to eq(code: '01457', name: 'Vonnas', postal_code: '01540', departement_code: '01', epci_code: '200070555', region_code: "84")
    end

    context 'with invalid department code' do
      it 'returns empty array' do
        expect(APIGeoService.communes(nil)).to eq([])
        expect(APIGeoService.communes('')).to eq([])
        expect(APIGeoService.communes('99')).to eq([])
      end
    end
  end

  describe 'communes_by_postal_code' do
    it 'return results', :slow do
      expect(APIGeoService.communes_by_postal_code('01500').size).to eq(8)
      expect(APIGeoService.communes_by_postal_code('75019').size).to eq(1)
      expect(APIGeoService.communes_by_postal_code('69005').size).to eq(1)
      expect(APIGeoService.communes_by_postal_code('13006').size).to eq(1)
      expect(APIGeoService.communes_by_postal_code('73480').size).to eq(3)
      expect(APIGeoService.communes_by_postal_code('20000').first[:code]).to eq('2A004')
      expect(APIGeoService.communes_by_postal_code('37160').size).to eq(7)
    end
  end

  describe 'commune_name' do
    subject { APIGeoService.commune_name('01', '01457') }
    it { is_expected.to eq('Vonnas') }

    context 'Paris' do
      subject { APIGeoService.commune_name('75', '75056') }
      it { is_expected.to eq('Paris') }
    end

    context 'Lyon' do
      subject { APIGeoService.commune_name('69', '69123') }
      it { is_expected.to eq('Lyon') }
    end

    context 'Marseille' do
      subject { APIGeoService.commune_name('13', '13055') }
      it { is_expected.to eq('Marseille') }
    end
  end

  describe 'commune_code' do
    subject { APIGeoService.commune_code('01', 'Vonnas') }
    it { is_expected.to eq('01457') }
  end

  describe 'epcis' do
    it 'return sorted results' do
      expect(APIGeoService.epcis('01').size).to eq(17)
      expect(APIGeoService.epcis('01').first).to eq(code: '200042935', name: 'CA Haut-Bugey Agglomération')
    end
  end

  describe 'parse_ban_address' do
    let(:features) { JSON.parse(Rails.root.join('spec/fixtures/files/api_address/address.json').read)['features'] }
    let(:feature) { features.first }
    subject { APIGeoService.parse_ban_address(feature) }

    context 'with a valid code insee' do
      it { expect(subject[:city_name]).to eq('Paris') }
    end

    context 'with an invalid code insee' do
      let(:feature) do
        features.first.tap {
          _1['properties']['citycode'] = '0000'
        }
      end

      it { expect(subject[:city_name]).to eq('Paris') }
    end

    context 'without postcode (nouméa…)' do
      let(:feature) do
        features.first.tap { _1["properties"].delete("postcode") }
      end

      it do
        expect(subject[:postal_code]).to eq('')
        expect(subject[:city_name]).to eq('Paris')
      end
    end
  end

  describe 'safely_normalize_city_name' do
    let(:department_code) { '75' }
    let(:city_code) { '75056' }
    let(:fallback) { 'Paris' }

    subject { APIGeoService.safely_normalize_city_name(department_code, city_code, fallback) }

    context 'nominal' do
      it { is_expected.to eq('Paris') }
    end

    context 'without department' do
      let(:department_code) { nil }

      it { is_expected.to eq('Paris') }
    end

    context 'without city_code' do
      let(:city_code) { nil }

      it { is_expected.to eq('Paris') }
    end

    context 'with blank department' do
      let(:department_code) { '' }

      it { is_expected.to eq('Paris') }
    end

    context 'with blank city_code' do
      let(:city_code) { '' }

      it { is_expected.to eq('Paris') }
    end
  end

  describe 'degraded mode' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('API_GEO_DEGRADED_MODE').and_return('enabled')
    end

    it 'returns commune results without calling API' do
      expect(Typhoeus).not_to receive(:get)

      response = APIGeoService.commune_by_name_or_postal_code('stras')
      results = JSON.parse(response.body)
      expect(results[0]["nom"]).to eq("Strasbourg")

      response = APIGeoService.commune_by_name_or_postal_code('41000')
      results = JSON.parse(response.body)
      expect(results[0]["nom"]).to eq("Blois")
    end
  end

  describe 'memoization helper' do
    before { APIGeoService.send(:reset_memo!) }
    after  { APIGeoService.send(:reset_memo!) }

    it 'caches the block result for repeated calls with the same key' do
      counter = 0
      first  = APIGeoService.send(:memoize, :test_key) { counter += 1; counter }
      second = APIGeoService.send(:memoize, :test_key) { counter += 1; counter }
      expect(first).to eq(1)
      expect(second).to eq(1)
      expect(counter).to eq(1)
    end

    it 'is keyed by the variadic argument list' do
      a = APIGeoService.send(:memoize, :ns, 'a') { 'value-a' }
      b = APIGeoService.send(:memoize, :ns, 'b') { 'value-b' }
      expect(a).to eq('value-a')
      expect(b).to eq('value-b')
    end

    it 'is cleared by reset_memo!' do
      counter = 0
      APIGeoService.send(:memoize, :test_key) { counter += 1 }
      APIGeoService.send(:reset_memo!)
      APIGeoService.send(:memoize, :test_key) { counter += 1 }
      expect(counter).to eq(2)
    end

    it 'returns frozen data from get_from_api_geo' do
      expect(APIGeoService.send(:get_from_api_geo, :regions)).to be_frozen
    end
  end

  describe 'static lists memoization' do
    before { APIGeoService.send(:reset_memo!) }
    after  { APIGeoService.send(:reset_memo!) }

    it 'memoizes regions' do
      first  = APIGeoService.regions
      second = APIGeoService.regions
      expect(second).to be(first)
      expect(first).to be_frozen
    end

    it 'memoizes departements' do
      first  = APIGeoService.departements
      second = APIGeoService.departements
      expect(second).to be(first)
      expect(first).to be_frozen
    end
  end

  describe 'per-departement memoization' do
    before { APIGeoService.send(:reset_memo!) }
    after  { APIGeoService.send(:reset_memo!) }

    it 'memoizes communes per departement code' do
      first  = APIGeoService.communes('01')
      second = APIGeoService.communes('01')
      expect(second).to be(first)
      expect(first).to be_frozen
    end

    it 'memoizes epcis per departement code' do
      first  = APIGeoService.epcis('01')
      second = APIGeoService.epcis('01')
      expect(second).to be(first)
      expect(first).to be_frozen
    end
  end

  describe 'postal-code index memoization' do
    before { APIGeoService.send(:reset_memo!) }
    after  { APIGeoService.send(:reset_memo!) }

    it 'memoizes communes_by_postal_code' do
      first  = APIGeoService.communes_by_postal_code('75019')
      second = APIGeoService.communes_by_postal_code('75019')
      expect(second).to be(first)
      expect(first).to be_frozen
    end

    it 'memoizes the postal-code inverted index map' do
      first  = APIGeoService.send(:communes_by_postal_code_map)
      second = APIGeoService.send(:communes_by_postal_code_map)
      expect(second).to be(first)
      expect(first).to be_frozen
    end
  end

  describe 'countries memoization' do
    before { APIGeoService.send(:reset_memo!) }
    after  { APIGeoService.send(:reset_memo!) }

    it 'memoizes countries per locale' do
      fr_first  = APIGeoService.countries(locale: 'FR')
      fr_second = APIGeoService.countries(locale: 'FR')
      en_first  = APIGeoService.countries(locale: 'EN')
      expect(fr_second).to be(fr_first)
      expect(en_first).not_to be(fr_first)
      expect(fr_first).to be_frozen
    end

    it 'memoizes the countries_index_fr lookup' do
      first  = APIGeoService.send(:countries_index_fr)
      second = APIGeoService.send(:countries_index_fr)
      expect(second).to be(first)
      expect(first).to be_frozen
    end
  end

  describe '.clean_address_query' do
    it 'strips and normalizes whitespace' do
      expect(described_class.clean_address_query("  20  avenue   Segur  ")).to eq("20 avenue Segur")
    end

    it 'removes leading non-alphanumeric chars' do
      expect(described_class.clean_address_query("...Paris")).to eq("Paris")
    end

    it 'returns nil for queries shorter than 3 chars' do
      expect(described_class.clean_address_query("ab")).to be_nil
    end

    it 'returns nil for nil input' do
      expect(described_class.clean_address_query(nil)).to be_nil
    end

    it 'truncates queries longer than 200 chars' do
      long_query = "a" * 250
      result = described_class.clean_address_query(long_query)
      expect(result.length).to eq(200)
    end

    it 'returns a valid query as-is' do
      expect(described_class.clean_address_query("20 avenue de Segur")).to eq("20 avenue de Segur")
    end
  end
end
