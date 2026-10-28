# frozen_string_literal: true

describe PublicAddressResolver do
  describe '.addresses' do
    it 'returns the resolved addresses of a hostname' do
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34', '2606:2800:220:1::1'])

      expect(described_class.addresses('https://example.com/hook')).to eq(['93.184.216.34', '2606:2800:220:1::1'])
    end

    it 'returns nothing for an unresolvable host' do
      allow(Resolv).to receive(:getaddresses).and_return([])

      expect(described_class.addresses('https://example.com/hook')).to eq([])
    end

    it 'returns an IP literal without resolving' do
      expect(Resolv).not_to receive(:getaddresses)

      expect(described_class.addresses('http://93.184.216.34/hook')).to eq(['93.184.216.34'])
      expect(described_class.addresses('http://[::1]/hook')).to eq(['::1'])
    end

    it 'resolves an internationalized host in its ASCII form' do
      expect(Resolv).to receive(:getaddresses).with('xn--exmple-cua.fr').and_return(['93.184.216.34'])

      expect(described_class.addresses('https://exämple.fr/hook')).to eq(['93.184.216.34'])
    end

    it 'returns nothing for a missing host or an invalid URL' do
      expect(described_class.addresses('not a url')).to eq([])
      expect(described_class.addresses('https://')).to eq([])
    end
  end

  describe '.private_address?' do
    it 'flags private addresses, including IPv4-mapped IPv6' do
      expect(described_class.private_address?('192.168.1.1')).to be(true)
      expect(described_class.private_address?('::ffff:169.254.169.254')).to be(true)
      expect(described_class.private_address?('::1')).to be(true)
      expect(described_class.private_address?('93.184.216.34')).to be(false)
    end
  end

  describe '.request_url' do
    it 'lowercases the scheme and makes the host ASCII, as the pin expects' do
      expect(described_class.request_url('HTTPS://Exämple.FR/Hook?a=1')).to eq('https://xn--exmple-cua.fr/Hook?a=1')
    end
  end

  describe '.resolve_pin' do
    it 'builds a curl resolve entry for a hostname' do
      pin = described_class.resolve_pin('https://example.com/hook', ['93.184.216.34'])

      expect(pin).to be_an(FFI::AutoPointer)
      expect(pin).not_to be_null
    end

    it 'pins the port libcurl infers from an uppercase scheme' do
      expect(Ethon::Curl).to receive(:slist_append).with(nil, 'example.com:443:93.184.216.34').and_call_original

      described_class.resolve_pin('HTTPS://Example.com/hook', ['93.184.216.34'])
    end

    it 'returns nil for an IP literal (nothing to pin)' do
      expect(described_class.resolve_pin('http://93.184.216.34/hook', ['93.184.216.34'])).to be_nil
    end
  end
end
