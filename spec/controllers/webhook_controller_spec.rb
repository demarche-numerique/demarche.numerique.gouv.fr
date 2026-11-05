# frozen_string_literal: true

describe WebhookController, type: :controller do
  describe '#crisp' do
    let(:payload) do
      {
        "event" => "message:send",
        "data" => {
          "from" => "user",
          "user" => { "user_id" => "usager@exemple.fr" },
        },
      }
    end

    let(:body) { payload }
    let(:timestamp) { Time.current }

    before do
      stub_const('ENV', ENV.to_hash.merge('CRISP_WEBHOOK_SECRET' => 'testsecret'))
    end

    it 'processes the webhook when signature is valid' do
      expected_signature = OpenSSL::HMAC.hexdigest('sha256',
        'testsecret',
        "[#{timestamp};#{body.to_json}]")

      expect(Crisp::WebhookProcessor).to receive(:new).and_call_original

      request.headers.merge!({
        'X-Crisp-Request-Timestamp' => timestamp,
        'X-Crisp-Signature' => expected_signature,
      })

      post :crisp, params: body, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "doesn't process the webhook when signature is invalid" do
      expect(Crisp::WebhookProcessor).not_to receive(:new)

      request.headers.merge!({
        'X-Crisp-Request-Timestamp' => timestamp,
        'X-Crisp-Signature' => 'bad_signature',
      })

      post :crisp, params: body, as: :json
      expect(response).not_to have_http_status(:ok)
    end

    it 'compares signatures using a constant-time primitive' do
      expect(Crisp::WebhookProcessor).not_to receive(:new)
      expect(ActiveSupport::SecurityUtils).to receive(:secure_compare).at_least(:once).and_call_original

      request.headers.merge!({
        'X-Crisp-Request-Timestamp' => timestamp,
        'X-Crisp-Signature' => '0' * 64,
      })

      post :crisp, params: body, as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects requests with a missing signature header without invoking the comparison' do
      expect(Crisp::WebhookProcessor).not_to receive(:new)

      request.headers['X-Crisp-Request-Timestamp'] = timestamp

      post :crisp, params: body, as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe '#brevo' do
    let(:user) { users.usager }
    let(:payload) { { event: 'hard_bounce', email: user.email, ts_event: 1_793_610_300 } }

    before do
      stub_const('ENV', ENV.to_hash.merge('BREVO_WEBHOOK_TOKEN' => 'testtoken'))
    end

    it 'records the block when the token is valid' do
      request.headers['Authorization'] = 'Bearer testtoken'

      post :brevo, params: payload, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload).to have_attributes(brevo_last_blocked_at: Time.zone.at(1_793_610_300), brevo_blocked_reason: 'hard_bounce')
    end

    it 'rejects a wrong token' do
      request.headers['Authorization'] = 'Bearer wrongtoken'

      post :brevo, params: payload, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(user.reload.brevo_last_blocked_at).to be_nil
    end

    it 'rejects any token when none is configured' do
      stub_const('ENV', ENV.to_hash.except('BREVO_WEBHOOK_TOKEN'))
      request.headers['Authorization'] = 'Bearer testtoken'

      post :brevo, params: payload, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(user.reload.brevo_last_blocked_at).to be_nil
    end

    context 'when the networks of Brevo are configured' do
      before do
        stub_const('ENV', ENV.to_hash.merge('BREVO_WEBHOOK_TOKEN' => 'testtoken', 'BREVO_WEBHOOK_NETWORKS' => '1.179.112.0/20 172.246.240.0/20'))
        request.headers['Authorization'] = 'Bearer testtoken'
      end

      it 'accepts a request from one of them' do
        request.remote_addr = '172.246.241.7'

        post :brevo, params: payload, as: :json

        expect(response).to have_http_status(:ok)
        expect(user.reload.brevo_blocked_reason).to eq('hard_bounce')
      end

      it 'rejects a request from elsewhere, even with the token' do
        request.remote_addr = '203.0.113.7'

        post :brevo, params: payload, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(user.reload.brevo_last_blocked_at).to be_nil
      end
    end
  end
end
