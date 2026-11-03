# frozen_string_literal: true

describe DeviceLabel do
  subject { described_class.new(user_agent).to_s }

  context 'Chrome on macOS' do
    let(:user_agent) { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36' }

    it { is_expected.to eq('Chrome sur macOS') }
  end

  context 'Safari on iOS' do
    let(:user_agent) { 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1' }

    it { is_expected.to eq('Safari sur iOS') }
  end

  context 'Edge on Windows' do
    let(:user_agent) { 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 Edg/128.0.0.0' }

    it { is_expected.to eq('Edge sur Windows') }
  end

  context 'Firefox on Linux' do
    let(:user_agent) { 'Mozilla/5.0 (X11; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0' }

    it { is_expected.to eq('Firefox sur Linux') }
  end

  context 'Chrome on iOS, which claims to be Safari' do
    let(:user_agent) { 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/126.0.6478.54 Mobile/15E148 Safari/604.1' }

    it { is_expected.to eq('Chrome sur iOS') }
  end

  context 'Firefox on iOS' do
    let(:user_agent) { 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/127.0 Mobile/15E148 Safari/605.1.15' }

    it { is_expected.to eq('Firefox sur iOS') }
  end

  context 'Edge on iOS' do
    let(:user_agent) { 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/126.0.2592.87 Mobile/15E148 Safari/605.1.15' }

    it { is_expected.to eq('Edge sur iOS') }
  end

  context 'a browser it cannot place' do
    let(:user_agent) { 'Chrome/128.0.0.0' }

    it { is_expected.to eq('Chrome') }
  end

  context 'nothing usable' do
    let(:user_agent) { 'curl/8.4.0' }

    it { is_expected.to eq('Appareil inconnu') }
  end

  context 'nil' do
    let(:user_agent) { nil }

    it { is_expected.to eq('Appareil inconnu') }
  end
end
