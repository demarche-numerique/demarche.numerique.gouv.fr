# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::ConsentStatus do
  let(:user) { build(:user) }
  let(:client) { instance_double(Ami::Client, configured?: true) }

  before do
    allow(Ami::Client).to receive(:new).and_return(client)
    allow(Ami::RecipientFcHash).to receive(:call).with(user).and_return("abc123")
  end

  it 'is unknown when the user has no France Connect identity' do
    allow(Ami::RecipientFcHash).to receive(:call).with(user).and_return(nil)

    expect(described_class.call(user)).to eq(:unknown)
    expect(client).not_to have_received(:configured?)
  end

  it 'is unknown when the client is not configured' do
    allow(client).to receive(:configured?).and_return(false)

    expect(described_class.call(user)).to eq(:unknown)
  end

  it 'is granted when AMI answers a success' do
    allow(client).to receive(:consent).with("abc123").and_return(Dry::Monads::Success(nil))

    expect(described_class.call(user)).to eq(:granted)
  end

  it 'is not granted when AMI answers a 404' do
    allow(client).to receive(:consent).with("abc123")
      .and_return(Dry::Monads::Failure(API::Client::Error[:http, 404, false, "Not found"]))

    expect(described_class.call(user)).to eq(:not_granted)
  end

  it 'is unknown and reported when AMI fails' do
    allow(Sentry).to receive(:capture_message)
    allow(client).to receive(:consent).with("abc123")
      .and_return(Dry::Monads::Failure(API::Client::Error[:timeout, 0, true, "Operation timed out"]))

    expect(described_class.call(user)).to eq(:unknown)
    expect(Sentry).to have_received(:capture_message)
  end
end
