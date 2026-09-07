# frozen_string_literal: true

require 'rails_helper'

# Guards the monkeypatch in config/initializers/active_storage.rb that makes
# `download_chunk` ask the object storage for a byte range.
describe ActiveStorage::Service::OpenStackService, '#download_chunk' do
  subject(:service) { described_class.new(container: 'bucket', credentials: {}) }

  let(:client) { instance_double(Fog::OpenStack::Storage::Real) }

  before { allow(service).to receive(:client).and_return(client) }

  # The real client streams the body through the response block; its own body stays empty.
  def responding(status, body)
    lambda do |*, &block|
      block.call(body.b, 0, body.bytesize)
      Struct.new(:status).new(status)
    end
  end

  it 'asks for the range, whether its end is exclusive or inclusive' do
    allow(client).to receive(:get_object_range).and_invoke(responding(206, 'x' * 11))

    service.download_chunk('key', 0...4096)
    service.download_chunk('key', 10..20)

    expect(client).to have_received(:get_object_range).with('bucket', 'key', 0, 4095, &nil)
    expect(client).to have_received(:get_object_range).with('bucket', 'key', 10, 20, &nil)
  end

  it 'takes a 206 body as the slice, whatever the offset it starts at' do
    allow(client).to receive(:get_object_range).and_invoke(responding(206, 'X' * 4096))

    expect(service.download_chunk('key', 1_000_000...1_004_096)).to eq(('X' * 4096).b)
  end

  it 'slices the body itself when the server answers 200 with the whole object' do
    allow(client).to receive(:get_object_range).and_invoke(responding(200, '0123456789'))

    expect(service.download_chunk('key', 4...8)).to eq('4567'.b)
  end

  it 'counts bytes, not characters' do
    # "é" is two bytes in UTF-8: a character slice would return two characters.
    allow(client).to receive(:get_object_range).and_invoke(responding(200, 'éa'))

    expect(service.download_chunk('key', 0...2)).to eq('é'.b)
  end

  it 'translates a missing object into the Active Storage error' do
    allow(client).to receive(:get_object_range).and_raise(Fog::OpenStack::Storage::NotFound)

    expect { service.download_chunk('key', 0...4096) }.to raise_error(ActiveStorage::FileNotFoundError)
  end
end

describe Fog::OpenStack::Storage::Real, '#get_object_range' do
  subject(:real) { described_class.allocate }

  let(:captured) { {} }

  before do
    allow(real).to receive(:request) do |params, _|
      captured.merge!(params)
      Struct.new(:status).new(206)
    end
  end

  it 'sends a GET carrying an inclusive HTTP Range header' do
    real.get_object_range('bucket', 'variants/a b', 0, 4095)

    expect(captured[:method]).to eq('GET')
    expect(captured[:headers]['Range']).to eq('bytes=0-4095')
    expect(captured[:path]).to eq('bucket/variants%2Fa%20b')
  end

  # Canary: the patch is only needed while the gem still downloads the whole
  # object. When it stops, this fails — the signal to drop the patch and this file.
  it 'is still needed: the gem downloads the whole object to serve a chunk' do
    source_file = File.join(
      Gem.loaded_specs.fetch('activestorage-openstack').gem_dir,
      'lib/active_storage/service/open_stack_service.rb'
    )

    expect(File.read(source_file)).to include('chunk_buffer.join[range]')
  end
end

# The doubles above pin the slicing; only a real socket pins what fog and Excon do
# with the range.
describe ActiveStorage::Service::OpenStackService, 'against a real HTTP server' do
  subject(:service) do
    described_class.new(
      container: 'bucket',
      credentials: {
        openstack_auth_token: 'token',
        openstack_auth_url: "http://127.0.0.1:#{port}/v3",
        openstack_management_url: "http://127.0.0.1:#{port}/v1/AUTH_test",
      }
    )
  end

  let(:payload) { (0...5_000).map { it % 251 }.pack('C*') }
  let(:server) { TCPServer.new('127.0.0.1', 0) }
  let(:port) { server.addr[1] }
  let(:requests) { [] }

  # `answer` receives the request headers and returns the raw response to write.
  def serve
    Thread.new do
      socket = server.accept
      headers = {}
      socket.gets
      while (line = socket.gets) && line != "\r\n"
        key, value = line.split(': ', 2)
        headers[key.downcase] = value.to_s.strip
      end
      requests << headers
      socket.write(yield(headers))
      socket.close
    end
  end

  after { server.close }

  it 'asks for the range and slices what a ds_proxy-shaped answer returns' do
    thread = serve do |headers|
      first, last = headers['range'].match(/bytes=(\d+)-(\d+)/).captures.map(&:to_i)
      body = payload.byteslice(first, last - first + 1)
      "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes #{first}-#{last}/#{payload.bytesize}\r\n" \
        "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
    end

    expect(service.download_chunk('key', 1_000...1_100)).to eq(payload.byteslice(1_000, 100))
    thread.join(5)
    expect(requests.last['range']).to eq('bytes=1000-1099')
  end

  it 'slices locally when the server ignores the range' do
    thread = serve do
      "HTTP/1.1 200 OK\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}"
    end

    expect(service.download_chunk('key', 1_000...1_100)).to eq(payload.byteslice(1_000, 100))
    thread.join(5)
  end

  it 'raises rather than handing back the error page of an unsatisfiable range' do
    body = '<html>Requested Range Not Satisfiable</html>'
    thread = serve do
      "HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */0\r\n" \
        "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
    end

    expect { service.download_chunk('key', 0...4096) }
      .to raise_error(Excon::Error::RequestedRangeNotSatisfiable)
    thread.join(5)
  end
end
