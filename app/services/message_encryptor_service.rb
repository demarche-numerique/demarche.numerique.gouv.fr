# frozen_string_literal: true

class MessageEncryptorService
  delegate :encrypt_and_sign, to: :@encryptor

  def initialize
    len = ActiveSupport::MessageEncryptor.key_len
    key = Rails.application.secret_key_base[0, len]
    @encryptor = ActiveSupport::MessageEncryptor.new(key, url_safe: true)

    # Verifier pendant la transition verifier => encryptor
    @verifier = ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base)
  end

  # Let controllers handle errors like they want
  def decrypt_and_verify(message, purpose: nil)
    @encryptor.decrypt_and_verify(message, purpose:)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage => original_error
    # Ce n’est pas un message chiffré, on essaie juste de le décoder s’il avait été simplement signé
    begin
      @verifier.verify(message, purpose:)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise original_error
    end
  end
end
