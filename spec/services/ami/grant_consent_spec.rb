# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::GrantConsent do
  let(:user) { build(:user) }
  let(:client) { instance_double(Ami::Client, configured?: true) }

  before do
    allow(Ami::Client).to receive(:new).and_return(client)
    allow(Ami::RecipientFcHash).to receive(:call).with(user).and_return("abc123")
  end

  it 'fails without calling AMI when the user has no France Connect identity' do
    allow(Ami::RecipientFcHash).to receive(:call).with(user).and_return(nil)

    expect(described_class.call(user)).to be_failure
  end

  it 'fails when the client is not configured' do
    allow(client).to receive(:configured?).and_return(false)

    expect(described_class.call(user)).to be_failure
  end

  it 'succeeds when AMI accepts the consent' do
    allow(client).to receive(:grant_consent).with("abc123").and_return(Dry::Monads::Success(nil))

    expect(described_class.call(user)).to be_success
  end

  it 'fails and relays the error when AMI rejects the call' do
    error = API::Client::Error[:http, 500, true, "Boom"]
    allow(client).to receive(:grant_consent).with("abc123").and_return(Dry::Monads::Failure(error))

    result = described_class.call(user)

    expect(result).to be_failure
    expect(result.failure).to eq(error)
  end
end
