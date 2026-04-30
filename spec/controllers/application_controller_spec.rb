# frozen_string_literal: true

describe ApplicationController, type: :controller do
  describe 'before_action: set_sentry_user' do
    it 'is present' do
      before_actions = ApplicationController
        ._process_action_callbacks
        .filter { |process_action_callbacks| process_action_callbacks.kind == :before }
        .map(&:filter)

      expect(before_actions).to include(:set_sentry_user)
      expect(before_actions).to include(:redirect_if_untrusted)
    end
  end

  describe 'set_sentry_user and append_info_to_payload' do
    let(:current_user) { nil }
    let(:current_instructeur) { nil }
    let(:current_administrateur) { nil }
    let(:current_super_admin) { nil }
    let(:payload) { {} }

    before do
      allow(@controller).to receive(:media_type).and_return('text/plain')
      allow(@controller).to receive(:current_user).and_return(current_user)
      expect(@controller).to receive(:current_instructeur).and_return(current_instructeur)
      expect(@controller).to receive(:current_administrateur).at_least(:once).and_return(current_administrateur)
      expect(@controller).to receive(:current_super_admin).and_return(current_super_admin)
      allow(Sentry).to receive(:set_user)

      @controller.send(:set_sentry_user)
      @controller.send(:append_info_to_payload, payload)
    end

    context 'when no one is logged in' do
      it "configure sentry guest" do
        expect(Sentry).to have_received(:set_user)
          .with({ id: 'Guest' })
      end

      it "configure loggable context" do
        [:db_runtime, :view_runtime, :variant, :rendered_format].each do |key|
          payload.delete(key)
        end
        expect(payload[:to_log].compact).to eq({
          user_agent: 'Rails Testing',
          user_roles: 'Guest',
          client_ip: request.remote_ip,
        })
      end
    end

    context 'when a user is logged in' do
      let(:current_user) { create(:user) }

      it "configure sentry user" do
        expect(Sentry).to have_received(:set_user)
          .with({ id: "User##{current_user.id}" })
      end

      it "configure loggable context" do
        [:db_runtime, :view_runtime, :variant, :rendered_format].each do |key|
          payload.delete(key)
        end
        expect(payload[:to_log].compact).to eq({
          user_agent: 'Rails Testing',
          user_id: current_user.id,
          user_roles: 'User',
          client_ip: request.remote_ip,
        })
      end
    end

    context 'when someone is logged as a user, instructeur, administrateur and super_admin' do
      let(:current_user) { create(:user) }
      let(:current_instructeur) { create(:instructeur) }
      let(:current_administrateur) { administrateurs(:default_admin) }
      let(:current_super_admin) { create(:super_admin) }

      it "configure sentry user" do
        expect(Sentry).to have_received(:set_user)
          .with({ id: "User##{current_user.id}" })
      end

      it "configure loggable context" do
        [:db_runtime, :view_runtime, :variant, :rendered_format].each do |key|
          payload.delete(key)
        end
        expect(payload[:to_log].compact).to eq({
          user_agent: 'Rails Testing',
          user_id: current_user.id,
          user_roles: 'User, Instructeur, Administrateur, SuperAdmin',
          client_ip: request.remote_ip,
        })
      end
    end
  end

  describe 'reject before action' do
    let(:path_info) { '/one_path' }

    before do
      allow(@controller).to receive(:redirect_to)
      allow(@controller).to receive(:sign_out)
      allow(@controller).to receive(:render)
      @request.path_info = path_info
    end

    context 'when no super_admin is logged in' do
      before { @controller.send(:reject) }

      it do
        expect(@controller).to have_received(:sign_out).with(:user)
        expect(@controller).to have_received(:sign_out).with(:instructeur)
        expect(@controller).to have_received(:sign_out).with(:administrateur)
        expect(flash[:alert]).to eq(ApplicationController::MAINTENANCE_MESSAGE)
        expect(@controller).to have_received(:redirect_to).with(root_path)
      end

      context 'when the path is safe' do
        ['/', '/manager', '/super_admins'].each do |path|
          let(:path_info) { path }

          it do
            expect(@controller).not_to have_received(:sign_out)
            expect(@controller).not_to have_received(:redirect_to)
            expect(flash.alert).to eq(ApplicationController::MAINTENANCE_MESSAGE)
          end
        end
      end

      context 'when the path is api related' do
        let(:path_info) { '/api/some-stuff' }
        let(:json_error) { { error: ApplicationController::MAINTENANCE_MESSAGE }.to_json }
        it do
          expect(@controller).not_to have_received(:sign_out)
          expect(@controller).not_to have_received(:redirect_to)
          expect(flash.alert).to be_nil
          expect(@controller).to have_received(:render).with({ json: json_error, status: :service_unavailable })
        end
      end
    end

    context 'when a super_admin is logged in' do
      let(:current_super_admin) { create(:super_admin) }

      before do
        sign_in(current_super_admin)
        @controller.send(:reject)
      end

      it do
        expect(@controller).not_to have_received(:sign_out)
        expect(@controller).not_to have_received(:redirect_to)
        expect(flash[:alert]).to eq(ApplicationController::MAINTENANCE_MESSAGE)
      end
    end
  end

  describe '#redirect_if_unstrusted' do
    let(:current_instructeur) { create(:instructeur) }

    before do
      allow(@controller).to receive(:current_instructeur).and_return(current_instructeur)
      allow(@controller).to receive(:redirect_to)
      allow(@controller).to receive(:trusted_device?).and_return(trusted_device)
      allow(@controller).to receive(:instructeur_signed_in?).and_return(instructeur_signed_in)
      allow(@controller).to receive(:sensitive_path).and_return(sensitive_path)
      allow(@controller).to receive(:send_login_token_or_bufferize)
      allow(@controller).to receive(:get_stored_location_for).and_return(nil)
      allow(@controller).to receive(:store_location_for)
      allow(IPService).to receive(:ip_trusted?).and_return(ip_trusted)
      allow(@controller).to receive(:pro_connect_mfa?).and_return(pro_connect_mfa)
    end

    subject { @controller.send(:redirect_if_untrusted) }

    context 'when the path is sensitive' do
      let(:sensitive_path) { true }

      before do
        current_instructeur.update!(bypass_email_login_token: false)
      end

      context 'when the instructeur is signed_in' do
        let(:instructeur_signed_in) { true }

        context 'when the ip is not trusted' do
          let(:ip_trusted) { false }

          context 'when the device is trusted' do
            let(:trusted_device) { true }

            context 'when the user used mfa' do
              let(:pro_connect_mfa) { true }

              before { subject }

              it { expect(@controller).not_to have_received(:redirect_to) }
            end

            context 'when the user does not used mfa' do
              let(:pro_connect_mfa) { false }

              before { subject }

              it { expect(@controller).not_to have_received(:redirect_to) }
            end
          end

          context 'when the device is not trusted' do
            let(:trusted_device) { false }

            context 'when the user used mfa' do
              let(:pro_connect_mfa) { true }

              before { subject }

              it do
                expect(@controller).not_to have_received(:redirect_to)
                expect(response).to have_http_status(:ok)
              end
            end

            context 'when the user did not use mfa' do
              let(:pro_connect_mfa) { false }

              before { subject }

              it do
                expect(@controller).to have_received(:redirect_to)
                expect(@controller).to have_received(:send_login_token_or_bufferize)
                expect(@controller).to have_received(:store_location_for)
              end
            end
          end
        end

        context 'when the ip is trusted' do
          let(:ip_trusted) { true }

          context 'when the device is not trusted and the user does not uses mfa' do
            let(:trusted_device) { false }
            let(:pro_connect_mfa) { false }

            before { subject }

            it { expect(@controller).not_to have_received(:redirect_to) }
          end
        end
      end
    end
  end

  describe '#redirect_if_untrusted IP source (security: 2FA bypass via X-Forwarded-For spoofing)' do
    let(:current_instructeur) { create(:instructeur) }

    before do
      current_instructeur.update!(bypass_email_login_token: false)
      allow(@controller).to receive(:current_instructeur).and_return(current_instructeur)
      allow(@controller).to receive(:redirect_to)
      allow(@controller).to receive(:trusted_device?).and_return(false)
      allow(@controller).to receive(:instructeur_signed_in?).and_return(true)
      allow(@controller).to receive(:sensitive_path).and_return(true)
      allow(@controller).to receive(:send_login_token_or_bufferize)
      allow(@controller).to receive(:get_stored_location_for).and_return(nil)
      allow(@controller).to receive(:store_location_for)
      allow(@controller).to receive(:pro_connect_mfa?).and_return(false)
      @request.headers['X-Forwarded-For'] = '10.0.0.1'
    end

    it 'passes request.remote_ip to IPService, not the raw X-Forwarded-For header' do
      expect(IPService).to receive(:ip_trusted?).with(@controller.request.remote_ip)
      @controller.send(:redirect_if_untrusted)
    end
  end

  describe 'crisp_config and crisp_segments' do
    before do
      allow(ENV).to receive(:enabled?).with("CRISP").and_return(true)
      allow(ENV).to receive(:fetch).with("CRISP_WEBSITE_ID").and_return("test-website-id")
    end

    context 'when a simple user is logged in' do
      let(:user) { create(:user) }

      before do
        allow(@controller).to receive(:current_user).and_return(user)
        allow(@controller).to receive(:user_signed_in?).and_return(true)
        allow(@controller).to receive(:administrateur_signed_in?).and_return(false)
        allow(@controller).to receive(:instructeur_signed_in?).and_return(false)
        allow(@controller).to receive(:expert_signed_in?).and_return(false)
      end

      it 'returns usager segment' do
        config = @controller.send(:crisp_config)
        expect(config[:user][:email]).to eq(user.email)
        expect(config[:user][:segments]).to eq(['usager'])
      end
    end

    context 'when an administrateur is logged in' do
      let(:administrateur) { administrateurs(:default_admin) }

      before do
        allow(@controller).to receive(:current_user).and_return(administrateur.user)
        allow(@controller).to receive(:user_signed_in?).and_return(true)
        allow(@controller).to receive(:administrateur_signed_in?).and_return(true)
      end

      it 'returns administrateur and instructeur segments' do
        config = @controller.send(:crisp_config)
        expect(config[:user][:segments]).to contain_exactly('administrateur', 'instructeur')
      end
    end

    context 'when an instructeur is logged in' do
      let(:instructeur) { create(:instructeur) }

      before do
        allow(@controller).to receive(:current_user).and_return(instructeur.user)
        allow(@controller).to receive(:user_signed_in?).and_return(true)
        allow(@controller).to receive(:instructeur_signed_in?).and_return(true)
      end

      it 'returns instructeur segment' do
        config = @controller.send(:crisp_config)
        expect(config[:user][:segments]).to eq(['instructeur'])
      end
    end

    context 'on brouillon page' do
      before do
        allow(@controller).to receive(:controller_path).and_return('users/dossiers')
        allow(@controller).to receive(:action_name).and_return('brouillon')
        allow(@controller).to receive(:matomo_config)
        allow(@controller).to receive(:sentry_config)
      end

      it 'does not setup crisp' do
        expect(@controller).not_to receive(:crisp_config)
        @controller.send(:setup_tracking)
      end
    end
  end

  describe 'crisp_email_signature' do
    subject { @controller.send(:crisp_email_signature) }

    let(:user) { nil }
    let(:private_key) { nil }

    before do
      allow(@controller).to receive(:current_user).and_return(user)
      allow(ENV).to receive(:[]).with("CRISP_IDENTITY_PRIVATE_KEY").and_return(private_key)
    end

    context 'without a current user' do
      it { is_expected.to be_nil }
    end

    context 'with an unverified user' do
      let(:user) { create(:user, email_verified_at: nil) }

      it { is_expected.to be_nil }
    end

    context 'with a verified user but no CRISP_IDENTITY_PRIVATE_KEY' do
      let(:user) { create(:user, email_verified_at: Time.zone.now) }

      it { is_expected.to be_nil }
    end

    context 'with a verified user and CRISP_IDENTITY_PRIVATE_KEY set' do
      let(:user) { create(:user, email: 'test@example.com', email_verified_at: Time.zone.now) }
      let(:private_key) { 'test-secret-key' }

      it { is_expected.to eq(OpenSSL::HMAC.hexdigest("sha256", private_key, user.email)) }
    end
  end
end
