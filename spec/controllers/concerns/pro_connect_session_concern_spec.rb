# frozen_string_literal: true

RSpec.describe ProConnectSessionConcern, type: :controller do
  class TestController < ActionController::Base
    include ProConnectSessionConcern
  end

  controller TestController do
  end

  describe '#set_pro_connect_session_info_cookie and #session_info' do
    before do
      controller.set_pro_connect_session_info_cookie(42, mfa: true)
      allow(controller).to receive(:current_user).and_return(double(id: user_id))
    end

    describe 'when the user id matches' do
      let(:user_id) { 42 }

      it 'stores and retrieves the session info correctly' do
        expect(controller.logged_in_with_pro_connect?).to be true
        expect(controller.pro_connect_mfa?).to be true
      end
    end

    describe 'when the user id does not match' do
      let(:user_id) { 43 }

      it 'does not retrieve the session info' do
        expect(controller.logged_in_with_pro_connect?).to be false
        expect(controller.pro_connect_mfa?).to be false
      end
    end

    describe 'when the mfa assertion is older than TRUSTED_DEVICE_PERIOD' do
      let(:user_id) { 42 }

      it 'is no longer considered valid' do
        travel_to Time.zone.local(2026, 1, 1) do
          controller.set_pro_connect_session_info_cookie(42, mfa: true)
        end

        travel_to Time.zone.local(2026, 2, 5) do
          expect(controller.pro_connect_mfa?).to be false
        end
      end
    end

    describe 'with a cookie without mfa_at' do
      let(:user_id) { 42 }

      before do
        controller.send(:cookies).encrypted[ProConnectSessionConcern::SESSION_INFO_COOKIE_NAME] = { user_id: 42, mfa: true }.to_json
      end

      it { expect(controller.pro_connect_mfa?).to be false }
    end
  end
end
