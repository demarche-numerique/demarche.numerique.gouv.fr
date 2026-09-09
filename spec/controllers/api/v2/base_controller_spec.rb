# frozen_string_literal: true

describe API::V2::BaseController, type: :controller do
  describe 'ensure_authorized_network and token_is_not_expired' do
    let(:admin) { administrateurs.default }
    let(:token_bearer_couple) { APIToken.generate(admin) }
    let(:token) { token_bearer_couple[0] }
    let(:bearer) { token_bearer_couple[1] }
    let(:remote_ip) { '0.0.0.0' }

    controller(API::V2::BaseController) do
      def fake_action
        context
        render(plain: 'Hello, World!')
      end
    end

    before do
      ActionController::Base.allow_forgery_protection = true
      routes.draw { get 'fake_action' => 'api/v2/base#fake_action' }
      routes.draw { post 'fake_action' => 'api/v2/base#fake_action' }
    end

    after { ActionController::Base.allow_forgery_protection = false }

    describe 'with token' do
      before do
        valid_headers = { 'Authorization' => "Bearer token=#{bearer}" }
        request.headers.merge!(valid_headers)
        request.remote_ip = remote_ip
      end

      describe 'POST #fake_action' do
        subject { post :fake_action }

        context 'when no authorized networks are defined and the token is not expired' do
          it { is_expected.to have_http_status(:ok) }
        end

        context 'when the token is expired' do
          before do
            token.update!(expires_at: 1.day.ago)
          end

          it { is_expected.to have_http_status(:unauthorized) }
        end

        context 'when this is precisely the day the token expires' do
          before do
            token.update!(expires_at: Time.zone.today)
          end

          it { is_expected.to have_http_status(:ok) }
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

    describe 'with a signed-in admin session but no token' do
      before { sign_in(admin.user) }

      describe 'POST #fake_action' do
        it 'ignores the session and rejects the request like an unauthenticated one' do
          post :fake_action

          expect(response).to have_http_status(:forbidden)
          expect(controller.send(:current_user)).to be_nil
          expect(Current.user).to be_nil
        end

        it 'allows public queries without any identity' do
          post :fake_action, params: { queryId: 'introspection' }

          expect(response).to have_http_status(:ok)
          expect(controller.send(:context)).to include(administrateur_id: nil, procedure_ids: [], write_access: false)
        end
      end
    end

    describe 'without token' do
      describe 'GET #index' do
        let(:params) { {} }
        subject { get :fake_action, params: }

        context 'without token and not logged in' do
          it { is_expected.to have_http_status(:forbidden) }
        end

        context 'with a random queryId' do
          let(:params) { { queryId: '123' } }
          it { is_expected.to have_http_status(:forbidden) }
        end

        context 'with an introspection query' do
          let(:params) { { queryId: 'introspection' } }
          it { is_expected.to have_http_status(:ok) }
        end
      end
    end
  end
end
