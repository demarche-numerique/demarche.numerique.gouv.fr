# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CrispTchapTechNotificationJob, type: :job do
  let(:user) { users.usager }
  let(:session_id) { "session_310b13c9-f115-42f5-bd83-f5e22b8e50dd" }
  let(:website_id) { "test-website-id" }
  let(:inbox_id) { "123-456" }
  let(:token) { "bot-token" }
  let(:job) { described_class.new(session_id) }
  let(:tchap_url) { "#{TCHAP_HOMESERVER_URL}/_matrix/client/v3/rooms/%21nOYpnkgzYvikwhriOQ%3Aagent.dinum.tchap.gouv.fr/send/m.room.message/crisp-#{job.job_id}" }
  let(:topic) { "Technical issue with the platform" }
  let(:last_message) { "I need <b>help</b>\nwith the platform" }
  let(:meta_data) { { "Dossier" => "[Dossier #42](https://example.org/manager/dossiers/42)" } }

  subject { job.perform_now }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("CRISP_WEBSITE_ID").and_return(website_id)
    allow(ENV).to receive(:fetch).with("CRISP_CLIENT_IDENTIFIER").and_return("test-client-id")
    allow(ENV).to receive(:fetch).with("CRISP_CLIENT_KEY").and_return("test-client-key")
    allow(ENV).to receive(:fetch).with("CRISP_INBOX_ID_DEV", nil).and_return("123-456")
    allow(ENV).to receive(:fetch).with("TCHAP_BOT_BUGS_TOKEN", nil).and_return(token)
    allow(ENV).to receive(:fetch).with("TCHAP_BOT_BUGS_TOKEN").and_return(token)

    stub_request(:get, %r{^https://api.crisp.chat/v1/website/#{website_id}/conversation/#{session_id}$})
      .and_return(
        body: {
          "error" => false,
          "reason" => "resolved",
          "data" => {
            "inbox_id" => inbox_id,
            "session_id" => session_id,
            "topic" => topic,
            "last_message" => last_message,
            "waiting_since" => Time.parse("2025-09-02 15:12:12 +02:00").to_i * 1000,
            "meta" => {
              "email" => user.email,
              "segments" => ["customer", "tech"],
              "data" => meta_data,
            },
          },
        }.to_json
      )
    stub_request(:put, tchap_url).to_return do |request|
      @sent_message = JSON.parse(request.body)
      { body: { event_id: "$event" }.to_json }
    end
  end

  attr_reader :sent_message

  context 'when inbox matches' do
    it 'sends a notice with a plain text body and an html body' do
      subject

      expect(a_request(:put, tchap_url).with(headers: { "Authorization" => "Bearer #{token}" })).to have_been_made.once
      expect(sent_message).to include("msgtype" => "m.notice", "format" => "org.matrix.custom.html", "m.mentions" => {})

      [sent_message["body"], sent_message["formatted_body"]].each do |text|
        expect(text).to include(topic, user.email, "User ##{user.id}", "Dossier #42", "customer, tech", "02/09/2025 15:12")
        expect(text).to include("https://app.crisp.chat/website/#{website_id}/inbox/#{session_id}/")
      end
      expect(sent_message["body"]).to include(last_message)
    end

    it 'escapes the user content in the html body' do
      subject

      expect(sent_message["formatted_body"]).to include("I need &lt;b&gt;help&lt;/b&gt;<br>with the platform")
      expect(sent_message["formatted_body"]).not_to include("<b>")
    end

    context 'when the topic and the dossier metadata are forged' do
      let(:topic) { %(<a href="https://evil.example">x</a>) }
      let(:meta_data) { { "Dossier" => "[Dossier #42](https://evil.example)" } }

      it 'links only to our own urls' do
        subject

        expect(sent_message["formatted_body"]).not_to include('href="https://evil.example"')
        expect(sent_message["formatted_body"]).to include(%(href="#{Rails.application.routes.url_helpers.manager_dossier_url(42)}"))
      end
    end
  end

  context 'when the homeserver rejects the event' do
    before { stub_request(:put, tchap_url).to_return(status: 403, body: { errcode: "M_FORBIDDEN" }.to_json) }

    it 'reports it once instead of retrying' do
      expect(Sentry).to receive(:capture_exception).with(Tchap::APIService::RejectedError)

      expect { subject }.not_to have_enqueued_job(described_class)
    end
  end

  context 'when the last message is huge' do
    let(:last_message) { "a" * 100_000 }

    it 'truncates it' do
      subject

      expect(sent_message["body"].size).to be < 3_000
    end
  end

  context 'when inbox is not technical inbox' do
    let(:inbox_id) { "another-inbox" }

    it "does not send notification" do
      subject

      expect(a_request(:put, tchap_url)).not_to have_been_made
    end
  end

  context 'when the Tchap bot token is not configured' do
    let(:token) { nil }

    it 'does not fail nor send anything' do
      expect { subject }.not_to raise_error
      expect(a_request(:put, tchap_url)).not_to have_been_made
    end
  end
end
