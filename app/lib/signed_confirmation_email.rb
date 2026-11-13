# frozen_string_literal: true

module SignedConfirmationEmail
  PURPOSE = :email_confirmation

  def self.sign(email)
    MessageEncryptorService.new.encrypt_and_sign(email, purpose: PURPOSE, expires_in: 1.hour)
  end

  def self.read(signed_email)
    MessageEncryptorService.new.decrypt_and_verify(signed_email, purpose: PURPOSE)
  rescue StandardError
    nil
  end
end
