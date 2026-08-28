# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::ConsentStatus do
  let(:client) { instance_double(Ami::Client, configured?: true) }

  before { allow(Ami::Client).to receive(:new).and_return(client) }

  it 'cannot be asked without a France Connect identity' do
    expect(described_class.call(nil)).to eq(:unavailable)
    expect(client).not_to have_received(:configured?)
  end

  it 'cannot be asked when the client is not configured' do
    allow(client).to receive(:configured?).and_return(false)

    expect(described_class.call("abc123")).to eq(:unavailable)
  end

  it 'is granted when AMI dates the consent' do
    allow(client).to receive(:consent).with("abc123")
      .and_return(Dry::Monads::Success(consent_datetime: "2026-08-28T10:00:00Z"))

    expect(described_class.call("abc123")).to eq(:granted)
  end

  # Le schéma déclare consent_datetime nullable en 200 alors que la description
  # promet un 404 : on couvre les deux lectures du contrat.
  it 'is not granted when AMI answers a success without a date' do
    allow(client).to receive(:consent).with("abc123")
      .and_return(Dry::Monads::Success(consent_datetime: nil))

    expect(described_class.call("abc123")).to eq(:not_granted)
  end

  it 'is granted when AMI answers a success without a body' do
    allow(client).to receive(:consent).with("abc123").and_return(Dry::Monads::Success(nil))

    expect(described_class.call("abc123")).to eq(:granted)
  end

  it 'is not granted when AMI answers a 404' do
    allow(client).to receive(:consent).with("abc123")
      .and_return(Dry::Monads::Failure(API::Client::Error[:http, 404, false, "Not found"]))

    expect(described_class.call("abc123")).to eq(:not_granted)
  end

  it 'is unknown when AMI could not answer' do
    allow(client).to receive(:consent).with("abc123")
      .and_return(Dry::Monads::Failure(API::Client::Error[:timeout, 0, true, "Operation timed out"]))

    expect(described_class.call("abc123")).to eq(:unknown)
  end
end
