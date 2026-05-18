# frozen_string_literal: true

RSpec.describe Cron::OidcConfigRefreshJob, type: :job do
  describe '#perform' do
    subject { described_class.perform_now }

    before do
      ENV['FRANCE_CONNECT_ENABLED'] = "enabled"
      ENV['FC_PARTICULIER_BASE_URL_V2'] = "https://fc-particulier.test"
      ENV['PRO_CONNECT_BASE_URL'] = "https://pro-connect.test"
    end

    after do
      ENV['FRANCE_CONNECT_ENABLED'] = "disabled"
      ENV.delete('FC_PARTICULIER_BASE_URL_V2')
      ENV.delete('PRO_CONNECT_BASE_URL')
    end

    it "refreshes FranceConnectConfig" do
      expect(FranceConnectConfig).to receive(:refresh!)
      allow(ProConnectConfig).to receive(:refresh!)

      subject
    end

    it "refreshes ProConnectConfig" do
      allow(FranceConnectConfig).to receive(:refresh!)
      expect(ProConnectConfig).to receive(:refresh!)

      subject
    end
  end
end
