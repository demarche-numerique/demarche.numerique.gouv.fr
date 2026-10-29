# frozen_string_literal: true

describe SignedConfirmationEmail do
  let(:email) { 'usager@example.fr' }

  describe '.read' do
    it 'gives back the email that was signed' do
      expect(described_class.read(described_class.sign(email))).to eq(email)
    end

    it 'gives the email back until the signature is an hour old, then nothing' do
      signed_email = described_class.sign(email)

      travel 59.minutes
      expect(described_class.read(signed_email)).to eq(email)

      travel 2.minutes
      expect(described_class.read(signed_email)).to be_nil
    end

    it 'gives nothing back for a missing or unreadable value' do
      expect(described_class.read(nil)).to be_nil
      expect(described_class.read('pas-un-jeton')).to be_nil
      expect(described_class.read([email])).to be_nil
    end

    it 'gives nothing back for an email signed for another purpose' do
      signed_up_email = MessageEncryptorService.new.encrypt_and_sign(email, purpose: :signed_up_email, expires_in: 1.hour)

      expect(described_class.read(signed_up_email)).to be_nil
    end
  end
end
