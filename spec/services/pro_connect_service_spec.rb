# frozen_string_literal: true

describe ProConnectService do
  describe '.logout_url' do
    let(:id_token) { 'id_token' }

    before do
      allow(ProConnectConfig).to receive(:client_config).and_return({ end_session_endpoint: "https://www.proconnect.gouv.fr/logout" })
    end

    subject { described_class.logout_url(id_token, host_with_port: 'test.host') }

    it 'returns the correct url' do
      expect(subject).to eq("https://www.proconnect.gouv.fr/logout?id_token_hint=id_token&post_logout_redirect_uri=http%3A%2F%2Ftest.host%2Flogout")
    end
  end

  describe '.authorization_uri' do
    let(:force_mfa) { false }
    let(:login_hint) { nil }

    before do
      allow(described_class).to receive(:conf).and_return({
        client_id: 'client_id',
        identifier: 'client_id',
        client_secret: 'client_secret',
        redirect_uri: 'https://app.example.com/pro_connect/callback',
        authorization_endpoint: 'https://www.proconnect.gouv.fr/authorize',
      })
    end

    subject { described_class.authorization_uri(force_mfa:, login_hint:) }

    it 'returns uri, state and nonce' do
      uri, state, nonce = subject
      expect(uri).to be_a(String)
      expect(uri).not_to include('eidas2')
      expect(uri).not_to include('login_hint')

      expect(state).to be_a(String)
      expect(nonce).to be_a(String)
    end

    describe 'with force_mfa true' do
      let(:force_mfa) { true }

      it 'includes various acr values in the authorization uri' do
        uri, _state, _nonce = subject
        expect(uri).to include('eidas0-mfa')
        expect(uri).to include('eidas1-mfa')
        expect(uri).to include('eidas2')
        expect(uri).to include('eidas3')
      end
    end

    describe 'with login_hint' do
      let(:login_hint) { 'toto@a.com' }

      it 'includes the login_hint in the authorization uri' do
        uri, _state, _nonce = subject
        expect(uri).to include('login_hint=toto%40a.com')
      end
    end
  end

  describe '.mfa?' do
    it 'is true when amr or acr asserts a multi factor authentication' do
      expect(described_class.mfa?(amr: ['pwd', 'mail', 'mfa'], acr: nil)).to be true
      expect(described_class.mfa?(amr: ['pwd'], acr: 'eidas1-mfa')).to be true
    end

    it 'is false otherwise' do
      expect(described_class.mfa?(amr: ['pwd'], acr: 'eidas1')).to be false
    end
  end
end
