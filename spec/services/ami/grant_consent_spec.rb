# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::GrantConsent do
  let(:dossier) { dossiers.en_construction }

  # Tant qu'AMI n'expose pas d'écriture, c'est le premier événement qui fait foi.
  context 'while AMI has no consent write' do
    before { allow(Ami).to receive(:grant_consent_endpoint_available?).and_return(false) }

    it 'sends the dossier event, carrying the consent along' do
      allow(Ami::CreateNotificationService).to receive(:call)

      described_class.call(dossier:)

      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, grant_consent: true)
    end
  end

  context 'once AMI exposes a consent write' do
    let(:client) { instance_double(Ami::Client, grant_consent: Dry::Monads::Success(nil)) }

    before do
      allow(Ami).to receive(:grant_consent_endpoint_available?).and_return(true)
      allow(Ami::Client).to receive(:new).and_return(client)
      allow(Ami::RecipientFcHash).to receive(:call).and_return("abc123")
      allow(Ami::CreateNotificationService).to receive(:call)
    end

    it 'writes the consent instead of sending an event' do
      described_class.call(dossier:)

      expect(client).to have_received(:grant_consent).with("abc123")
      expect(Ami::CreateNotificationService).not_to have_received(:call)
    end
  end
end
