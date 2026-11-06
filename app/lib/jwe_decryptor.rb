# frozen_string_literal: true

# json-jwt cannot decrypt RSA-OAEP-256, the key wrapping FranceConnect+ encrypts its tokens with
module JweDecryptor
  module_function

  ALGORITHM = 'RSA-OAEP-256'
  ENCRYPTION = 'A256GCM'
  TAG_BYTES = 16

  def decrypt(token, private_key)
    protected_header, encrypted_key, iv, ciphertext, tag = token.split('.')

    header = JSON.parse(Base64.urlsafe_decode64(protected_header))
    if header.values_at('alg', 'enc') != [ALGORITHM, ENCRYPTION]
      raise JSON::JWE::UnexpectedAlgorithm.new("Unexpected #{header['alg']} + #{header['enc']}")
    end

    # OpenSSL checks only as many tag bytes as it is given
    auth_tag = Base64.urlsafe_decode64(tag)
    raise JSON::JWE::DecryptionFailed.new('Truncated authentication tag') if auth_tag.bytesize != TAG_BYTES

    content_key = private_key.decrypt(Base64.urlsafe_decode64(encrypted_key), {
      'rsa_padding_mode' => 'oaep',
      'rsa_oaep_md' => 'sha256',
      'rsa_mgf1_md' => 'sha256',
    })

    cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
    cipher.key = content_key
    cipher.iv = Base64.urlsafe_decode64(iv)
    cipher.auth_tag = auth_tag
    cipher.auth_data = protected_header
    cipher.update(Base64.urlsafe_decode64(ciphertext)) + cipher.final
  end
end
