# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::GrantConsent do
  let(:dossier) { dossiers.en_construction }
  let(:client) { instance_double(Ami::Client, grant_consent: result) }

  before do
    allow(Ami::Client).to receive(:new).and_return(client)
    allow(Ami::CreateNotificationService).to receive(:call)
  end

  context 'when AMI accepts the consent' do
    let(:result) { Dry::Monads::Success(message: "Consent given") }

    it 'grants the consent, then sends the dossier event' do
      expect(described_class.call(dossier:, fc_hash: "abc123")).to eq(:granted)

      expect(client).to have_received(:grant_consent).with("abc123")
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, skip_consent_check: true)
    end

    it 'computes the hash itself when the caller has none' do
      allow(Ami::RecipientFcHash).to receive(:call).with(dossier.user).and_return("def456")

      described_class.call(dossier:)

      expect(client).to have_received(:grant_consent).with("def456")
    end
  end

  context 'when AMI rejects the consent' do
    let(:result) { Dry::Monads::Failure(API::Client::Error[:http, 500, true, "Boom"]) }

    # Sans consentement enregistré, l'événement n'a pas à partir : son contenu
    # ne doit pas parvenir à AMI.
    it 'reports the error and sends no event' do
      expect(described_class.call(dossier:, fc_hash: "abc123")).to eq(:error)

      expect(Ami::CreateNotificationService).not_to have_received(:call)
    end
  end
end
