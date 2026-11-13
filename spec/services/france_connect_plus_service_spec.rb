# frozen_string_literal: true

# Cached, so the provider is discovered once per example
describe FranceConnectPlusService, :caching do
  around { |example| with_france_connect_plus_env { example.run } }

  before { stub_france_connect_plus_discovery }

  describe '.authorization_uri' do
    it 'asks for the eIDAS substantiel level' do
      uri, state, nonce = described_class.authorization_uri

      expect(Rack::Utils.parse_query(URI(uri).query)).to include(
        'client_id' => 'fcp_client_id',
        'redirect_uri' => 'http://test.host/france_connect_plus/callback',
        'acr_values' => 'eidas2',
        'state' => state,
        'nonce' => nonce
      )
    end
  end

  describe '.find_or_retrieve_france_connect_information' do
    let(:user_info) do
      {
        sub: 'fcp_sub',
        given_name: 'Angela Claire Louise',
        family_name: 'DUBOIS',
        birthdate: '1962-08-24',
        gender: 'female',
        birthplace: '75107',
        birthcountry: '99100',
        email: 'angela.dubois@example.org',
      }
    end

    it 'decrypts and verifies the tokens' do
      stub_france_connect_plus_tokens(id_token: france_connect_plus_id_token(nonce: 'a_nonce'), user_info:)

      fci, id_token = described_class.find_or_retrieve_france_connect_information('a_code', 'a_nonce')

      expect(fci).to have_attributes(
        france_connect_particulier_id: 'fcp_sub',
        given_name: 'Angela Claire Louise',
        family_name: 'DUBOIS',
        birthdate: Date.new(1962, 8, 24),
        gender: 'female',
        birthplace: '75107',
        birthcountry: '99100',
        email_france_connect: 'angela.dubois@example.org'
      )
      # Decrypted, to be sent back on logout
      expect(JSON::JWT.decode(id_token, FranceConnectPlusHelpers::SIGNING_PUBLIC_KEY)['nonce']).to eq('a_nonce')
    end

    it 'refuses a level below substantiel' do
      stub_france_connect_plus_tokens(id_token: france_connect_plus_id_token(nonce: 'a_nonce', acr: 'eidas1'), user_info:)

      expect { described_class.find_or_retrieve_france_connect_information('a_code', 'a_nonce') }
        .to raise_error(OpenIDConnect::ResponseObject::IdToken::InvalidToken, 'Invalid ID token: eIDAS level below substantiel')
    end
  end
end
