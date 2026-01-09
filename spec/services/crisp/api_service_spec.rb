# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crisp::APIService do
  let(:website_id) { 'test-website-id' }
  let(:service) { described_class.new }
  let(:email) { 'user@example.com' }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("CRISP_WEBSITE_ID").and_return(website_id)
    allow(ENV).to receive(:fetch).with("CRISP_CLIENT_IDENTIFIER").and_return('client-id')
    allow(ENV).to receive(:fetch).with("CRISP_CLIENT_KEY").and_return('client-key')
  end

  describe '#update_people_data' do
    let(:api_client) { instance_double(API::Client) }
    let(:body) { { "key" => "value" } }

    before do
      allow(API::Client).to receive(:new).and_return(api_client)
    end

    context 'when API call succeeds' do
      before do
        allow(api_client).to receive(:call).and_return(
          Dry::Monads::Success({ body: { "error" => false, reason: "updated", "data": {} } })
        )
      end

      it 'calls API with correct parameters' do
        result = service.update_people_data(email:, body:)

        expect(api_client).to have_received(:call).with(
          url: URI("https://api.crisp.chat/v1/website/#{website_id}/people/data/#{email}"),
          json: body,
          method: :patch,
          headers: { 'X-Crisp-Tier' => 'plugin' },
          userpwd: 'client-id:client-key'
        )

        expect(result).to be_success
      end
    end

    context 'when API call fails' do
      before do
        allow(api_client).to receive(:call).and_return(
          Dry::Monads::Failure({ code: 400, reason: 'Bad Request' })
        )
      end

      it 'returns failure result' do
        result = service.update_people_data(email:, body:)

        expect(result).to be_failure
      end
    end
  end

  describe '#create_conversation' do
    context 'when API call succeeds' do
      let(:session_id) { 'session_700c65e1-85e2-465a-b9ac-ecb5ec2c9881' }

      before do
        stub_request(:post, "https://api.crisp.chat/v1/website/#{website_id}/conversation")
          .with(headers: { 'X-Crisp-Tier' => 'plugin', 'Authorization': /Basic /, 'content_type': 'application/json' })
          .and_return(
            body: { "error" => false, "reason" => "added", "data" => { "session_id" => session_id } }.to_json
          )
      end

      it 'calls API with correct parameters' do
        result = service.create_conversation

        expect(result).to be_success
        expect(result.success.dig(:data, :session_id)).to eq(session_id)
      end
    end

    describe '#send_message' do
      let(:session_id) { 'session_310b13c9-f115-42f5-bd83-f5e22b8e50dd' }
      let(:body) do
        {
          type: 'text',
          from: 'user',
          origin: 'email',
          content: 'Hey there! Need help?',
          fingerprint: 12345,
          user: { type: 'participant' },
        }
      end

      context 'when API call succeeds' do
        before do
          stub_request(:post, "https://api.crisp.chat/v1/website/#{website_id}/conversation/#{session_id}/message")
            .with(headers: { 'X-Crisp-Tier' => 'plugin', 'Authorization': /Basic / })
            .and_return(
              body: { "error" => false, "reason" => "dispatched", "data" => { "fingerprint" => 12345 } }.to_json
            )
        end

        it 'calls API with correct parameters' do
          result = service.send_message(session_id: session_id, body: body)

          expect(result).to be_success
          expect(result.success.dig(:data, :fingerprint)).to eq(12345)
        end
      end
    end

    describe '#update_conversation_meta' do
      let(:session_id) { 'session_310b13c9-f115-42f5-bd83-f5e22b8e50dd' }
      let(:body) do
        {
          email: 'test@example.com',
          segments: ['lost'],
          ip: '82.12.34.45',
          subject: 'the subject',
        }
      end

      context 'when API call succeeds' do
        before do
          stub_request(:patch, "https://api.crisp.chat/v1/website/#{website_id}/conversation/#{session_id}/meta")
            .with(headers: { 'X-Crisp-Tier' => 'plugin', 'Authorization': /Basic / })
            .and_return(
              body: { "error" => false, "reason" => "updated", "data" => {} }.to_json
            )
        end

        it 'calls API with correct parameters' do
          result = service.update_conversation_meta(session_id: session_id, body: body)

          expect(result).to be_success
        end
      end
    end

    describe '#get_conversation' do
      let(:session_id) { 'session_310b13c9-f115-42f5-bd83-f5e22b8e50dd' }

      context 'when API call succeeds' do
        before do
          stub_request(:get, "https://api.crisp.chat/v1/website/#{website_id}/conversation/#{session_id}")
            .with(headers: { 'X-Crisp-Tier' => 'plugin', 'Authorization': /Basic / })
            .and_return(
              body: {
                "error" => false,
                "reason" => "resolved",
                "data" => {
                  "session_id" => session_id,
                  "last_message" => "J’ai un pb avec l’attestation",
                  "topic" => "Attestation issue",
                  "meta" => {
                    "email" => "test@example.com",
                    "segments" => ["attestation"],
                  },
                },
              }.to_json
            )
        end

        it 'calls API with correct parameters' do
          result = service.get_conversation(session_id: session_id)

          expect(result).to be_success
          expect(result.success.dig(:data, :topic)).to eq("Attestation issue")
          expect(result.success.dig(:data, :last_message)).to eq("J’ai un pb avec l’attestation")
          expect(result.success.dig(:data, :meta, :segments)).to eq(["attestation"])
        end
      end
    end
  end
end
