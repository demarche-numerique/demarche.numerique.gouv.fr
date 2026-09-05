# frozen_string_literal: true

describe NoPrivateIPURLValidator do
  describe '.private_ip?' do
    it 'catches private, loopback, link-local, CGNAT and NAT64 addresses' do
      [
        '127.0.0.1',
        '10.0.0.1',
        '172.16.0.1',
        '192.168.1.1',
        '169.254.169.254',
        '100.64.0.5',
        '0.0.0.0',
        '::1',
        'fc00::1',
        'fe80::1',
        '64:ff9b::a00:1',
      ].each do |ip|
        expect(described_class.private_ip?(ip)).to be(true), "expected #{ip} to be private"
      end
    end

    it 'catches IPv4-mapped IPv6 forms of private addresses' do
      ['::ffff:127.0.0.1', '::ffff:169.254.169.254', '::ffff:10.0.0.1'].each do |ip|
        expect(described_class.private_ip?(ip)).to be(true), "expected #{ip} to be private"
      end
    end

    it 'accepts public addresses' do
      ['93.184.216.34', '::ffff:93.184.216.34', '2606:2800:220:1::1'].each do |ip|
        expect(described_class.private_ip?(ip)).to be(false), "expected #{ip} to be public"
      end
    end

    it 'returns false for a hostname' do
      expect(described_class.private_ip?('example.com')).to be(false)
    end
  end

  describe '.vetted_public_addresses' do
    it 'returns the resolved addresses of a public hostname' do
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34', '2606:2800:220:1::1'])

      expect(described_class.vetted_public_addresses('https://example.com/hook')).to eq(['93.184.216.34', '2606:2800:220:1::1'])
    end

    it 'rejects a host when any resolved address is private (rebinding-style split answer)' do
      allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34', '192.168.1.1'])

      expect(described_class.vetted_public_addresses('https://example.com/hook')).to be_nil
    end

    it 'rejects an unresolvable host' do
      allow(Resolv).to receive(:getaddresses).and_return([])

      expect(described_class.vetted_public_addresses('https://example.com/hook')).to be_nil
    end

    it 'rejects private IP literals without resolving, including IPv4-mapped IPv6' do
      expect(Resolv).not_to receive(:getaddresses)

      expect(described_class.vetted_public_addresses('http://192.168.1.1/hook')).to be_nil
      expect(described_class.vetted_public_addresses('http://[::ffff:169.254.169.254]/hook')).to be_nil
      expect(described_class.vetted_public_addresses('http://[::1]/hook')).to be_nil
    end

    it 'accepts a public IP literal' do
      expect(described_class.vetted_public_addresses('http://93.184.216.34/hook')).to eq(['93.184.216.34'])
    end

    it 'rejects a missing host or an invalid URL' do
      expect(described_class.vetted_public_addresses('not a url')).to be_nil
      expect(described_class.vetted_public_addresses('https://')).to be_nil
    end
  end

  describe '.resolve_pin' do
    it 'builds a curl resolve entry for a hostname' do
      pin = described_class.resolve_pin('https://example.com/hook', ['93.184.216.34'])

      expect(pin).to be_an(FFI::AutoPointer)
      expect(pin).not_to be_null
    end

    it 'returns nil for an IP literal (nothing to pin)' do
      expect(described_class.resolve_pin('http://93.184.216.34/hook', ['93.184.216.34'])).to be_nil
    end
  end

  describe '#validate_each' do
    let(:model_class) do
      Class.new do
        include ActiveModel::Model
        attr_accessor :url
        validates :url, no_private_ip_url: true

        def self.name = 'TestModel'
      end
    end

    it 'rejects private IP literals, including IPv4-mapped IPv6' do
      ['http://127.0.0.1/a', 'http://100.64.0.5/a', 'http://[::ffff:127.0.0.1]/a'].each do |url|
        expect(model_class.new(url:)).not_to be_valid, "expected #{url} to be invalid"
      end
    end

    it 'accepts hostnames without resolving them at validation time' do
      expect(Resolv).not_to receive(:getaddresses)

      expect(model_class.new(url: 'https://example.com/a')).to be_valid
    end
  end
end
