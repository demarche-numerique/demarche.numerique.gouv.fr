# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::SendNotificationJob, type: :job do
  let(:client) { instance_double(Ami::Client, send_notification: result) }
  let(:payload) { { item_type: "dossier", item_id: "42", recipient_fc_hash: "abc123" } }
  let(:context) { { procedure: 12, dossier: 42, state: :en_instruction } }
  let(:result) { Dry::Monads::Success({ ok: true }) }

  before do
    allow(Ami::Client).to receive(:new).and_return(client)
    allow(Ami::ConsentStatus).to receive(:call).with("abc123").and_return(:granted)
  end

  it 'sends payload when the user consented' do
    described_class.perform_now(payload, context)

    expect(client).to have_received(:send_notification).with(payload)
  end

  it 'sends nothing when the user did not consent' do
    allow(Ami::ConsentStatus).to receive(:call).and_return(:not_granted)

    expect { described_class.perform_now(payload, context) }.not_to raise_error
    expect(client).not_to have_received(:send_notification)
  end

  it 'sends nothing when the consent cannot be asked' do
    allow(Ami::ConsentStatus).to receive(:call).and_return(:unavailable)

    expect { described_class.perform_now(payload, context) }.not_to raise_error
    expect(client).not_to have_received(:send_notification)
  end

  # Retrying is the only way not to lose the notification, and we must not
  # guess a consent we could not read.
  it 'sends nothing and raises when AMI could not answer the consent' do
    allow(Ami::ConsentStatus).to receive(:call).and_return(:unknown)

    expect { described_class.perform_now(payload, context) }.to raise_error(described_class::ConsentCheckError)
    expect(client).not_to have_received(:send_notification)
  end

  # The first notification is what grants the consent, so asking beforehand
  # would keep it from ever being sent.
  it 'sends without asking when the notification carries the consent' do
    described_class.perform_now(payload, context, skip_consent_check: true)

    expect(client).to have_received(:send_notification).with(payload)
    expect(Ami::ConsentStatus).not_to have_received(:call)
  end

  it 'sends nothing without a France Connect identity' do
    described_class.perform_now(payload.merge(recipient_fc_hash: nil), context)

    expect(client).not_to have_received(:send_notification)
  end

  it 'captures and swallows non-retryable errors' do
    non_retryable_error = API::Client::Error[:api_error, 400, false, StandardError.new("Invalid payload")]
    allow(client).to receive(:send_notification).and_return(Dry::Monads::Failure(non_retryable_error))
    allow(Sentry).to receive(:capture_exception)

    expect { described_class.perform_now(payload, context) }.to raise_error
    expect(Sentry).to have_received(:capture_exception).with(instance_of(RuntimeError), anything).once
  end
end
