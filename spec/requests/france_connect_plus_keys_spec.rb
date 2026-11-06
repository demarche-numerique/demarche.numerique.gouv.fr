# frozen_string_literal: true

describe 'GET /france_connect_plus/keys' do
  let_it_be(:private_key) { OpenSSL::PKey::RSA.generate(2048) }

  context 'when the encryption key is configured' do
    around do |example|
      ENV['FC_PLUS_ENC_PRIVATE_KEY'] = private_key.to_pem
      example.run
    ensure
      ENV.delete('FC_PLUS_ENC_PRIVATE_KEY')
    end

    it 'publishes the public part of the key only' do
      get '/france_connect_plus/keys'

      expect(response).to have_http_status(:ok)

      key = response.parsed_body.fetch('keys').sole
      expect(key).to eq(
        'kty' => 'RSA',
        'n' => Base64.urlsafe_encode64(private_key.n.to_s(2), padding: false),
        'e' => 'AQAB',
        'use' => 'enc',
        'alg' => 'RSA-OAEP-256',
        'kid' => JSON::JWK.new(private_key.public_key).thumbprint
      )
    end

    it 'skips the staging basic auth' do
      allow(StagingAuthService).to receive(:enabled?).and_return(true)

      get '/france_connect_plus/keys'

      expect(response).to have_http_status(:ok)
    end
  end

  context 'when the encryption key is not configured' do
    it do
      get '/france_connect_plus/keys'

      expect(response).to have_http_status(:not_found)
    end
  end
end
