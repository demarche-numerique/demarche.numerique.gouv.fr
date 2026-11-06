# frozen_string_literal: true

describe JweDecryptor do
  # Encrypted by jwcrypto, an implementation independent of ours
  let(:fixture) { JSON.parse(file_fixture('france_connect_plus/jwe_rsa_oaep_256_a256gcm.json').read) }
  let(:private_key) { JSON::JWK.new(fixture.fetch('key')).to_key }

  it 'decrypts a RSA-OAEP-256 + A256GCM token' do
    expect(described_class.decrypt(fixture.fetch('jwe'), private_key)).to eq('eyJhbGciOiJFUzI1NiJ9.payload.signature')
  end

  it 'rejects another key wrapping' do
    protected_header = Base64.urlsafe_encode64({ alg: 'RSA-OAEP', enc: 'A256GCM' }.to_json, padding: false)
    token = [protected_header, *fixture.fetch('jwe').split('.').drop(1)].join('.')

    expect { described_class.decrypt(token, private_key) }.to raise_error(JSON::JWE::UnexpectedAlgorithm)
  end

  it 'rejects a tampered ciphertext' do
    protected_header, encrypted_key, iv, ciphertext, tag = fixture.fetch('jwe').split('.')
    tampered = Base64.urlsafe_encode64(Base64.urlsafe_decode64(ciphertext).reverse, padding: false)
    token = [protected_header, encrypted_key, iv, tampered, tag].join('.')

    expect { described_class.decrypt(token, private_key) }.to raise_error(OpenSSL::Cipher::CipherError)
  end
end
