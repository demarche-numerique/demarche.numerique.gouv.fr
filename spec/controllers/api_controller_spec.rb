# frozen_string_literal: true

describe APIController, type: :controller do
  describe 'authenticate_from_token' do
    let(:procedure) { create(:procedure) }
    let(:admin) { procedure.administrateurs.first }

    subject do
      controller.send(:authenticate_from_token)
      assigns(:api_token)
    end

    context 'when the admin has not any token' do
      context 'and the token is not given' do
        it { is_expected.to be nil }
      end
    end

    context 'when the admin has a token' do
      let(:token_bearer_couple) { APIToken.generate(admin) }
      let(:token) { token_bearer_couple[0] }
      let(:bearer) { token_bearer_couple[1] }

      context 'and the token is given by params' do
        before { controller.params[:token] = bearer }

        it { is_expected.to eq(token) }
      end

      context 'and the token is given by header' do
        before do
          valid_headers = { 'Authorization' => "Bearer token=#{bearer}" }
          request.headers.merge!(valid_headers)
        end

        it { is_expected.to eq(token) }
      end

      context 'and the token is not given' do
        it { is_expected.to be nil }
      end
    end
  end

  describe 'ensure_authorized_network and token is not expired' do
    let(:admin) { administrateurs(:default_admin) }
    let(:token_bearer_couple) { APIToken.generate(admin) }
    let(:token) { token_bearer_couple[0] }
    let(:bearer) { token_bearer_couple[1] }
    let(:remote_ip) { '0.0.0.0' }

    controller(APIController) { def fake_action = render(plain: 'Hello, World!') }

    before do
      routes.draw { get 'fake_action' => 'api#fake_action' }
      valid_headers = { 'Authorization' => "Bearer token=#{bearer}" }
      request.headers.merge!(valid_headers)
      request.remote_ip = remote_ip
    end

    describe 'GET #index' do
      subject { get :fake_action }

      context 'when no authorized networks are defined and the token is not expired' do
        it { is_expected.to have_http_status(:ok) }
      end

      context 'when the token is expired' do
        before do
          token.update!(expires_at: 1.day.ago)
        end

        it { is_expected.to have_http_status(:unauthorized) }
      end

      context 'when requires_ip_filtering is true and no networks defined (auto-assign)' do
        before { token.update!(requires_ip_filtering: true, authorized_networks: []) }

        context 'first call assigns the IP and succeeds' do
          let(:remote_ip) { '10.20.30.40' }

          it do
            is_expected.to have_http_status(:ok)
            expect(token.reload.authorized_networks).to eq([IPAddr.new('10.20.30.40')])
          end
        end
      end

      context 'when requires_ip_filtering is false and no networks defined (legacy)' do
        before { token.update!(requires_ip_filtering: false, authorized_networks: []) }

        let(:remote_ip) { '10.20.30.40' }

        it 'does not auto-assign' do
          is_expected.to have_http_status(:ok)
          expect(token.reload.authorized_networks).to be_empty
        end
      end

      context 'when a single authorized network is defined' do
        before do
          token.update!(authorized_networks: [IPAddr.new('192.168.1.0/24')])
        end

        context 'and the request comes from it' do
          let(:remote_ip) { '192.168.1.23' }

          it { is_expected.to have_http_status(:ok) }
        end

        context 'and the request does not come from it' do
          let(:remote_ip) { '192.168.2.2' }

          it { is_expected.to have_http_status(:forbidden) }
        end
      end
    end
  end
end
