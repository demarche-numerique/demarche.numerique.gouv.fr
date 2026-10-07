# frozen_string_literal: true

describe Tchap::APIService do
  let(:token) { "s3cr3t-bot-token" }
  let(:room_id) { "!room:agent.dinum.tchap.gouv.fr" }
  let(:url) { "#{TCHAP_HOMESERVER_URL}/_matrix/client/v3/rooms/%21room%3Aagent.dinum.tchap.gouv.fr/send/m.room.message/txn%2F1" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("TCHAP_BOT_TOKEN").and_return(token)
  end

  subject { described_class.new.send_notice(room_id:, txn_id: "txn/1", body: "plain", formatted_body: "<p>html</p>") }

  it "PUTs an m.notice to the encoded room path with the bot token" do
    stub_request(:put, url).to_return(body: { event_id: "$event" }.to_json)
    # WebMock normalizes percent-encoding before matching: check the raw url
    expect_any_instance_of(API::Client).to receive(:call).with(hash_including(url:)).and_call_original

    subject

    expect(a_request(:put, url).with(
      headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" },
      body: {
        msgtype: "m.notice",
        body: "plain",
        format: "org.matrix.custom.html",
        formatted_body: "<p>html</p>",
        "m.mentions": {},
      }
    )).to have_been_made.once
  end

  context "when the homeserver is unavailable" do
    before { stub_request(:put, url).to_return(status: 502, body: "") }

    it { expect { subject }.to raise_error(RetryableFetchError) { expect(it.provider).to eq("Tchap") } }
  end

  context "when the homeserver is rate limiting" do
    before { stub_request(:put, url).to_return(status: 429, body: { errcode: "M_LIMIT_EXCEEDED" }.to_json) }

    it { expect { subject }.to raise_error(RetryableFetchError) }
  end

  context "when the token is rejected" do
    before { stub_request(:put, url).to_return(status: 401, body: { errcode: "M_UNKNOWN_TOKEN" }.to_json) }

    it "fails without retrying as an outage nor leaking the token" do
      expect { subject }.to raise_error(described_class::RejectedError) { expect(it.message).not_to include(token) }
    end
  end
end
