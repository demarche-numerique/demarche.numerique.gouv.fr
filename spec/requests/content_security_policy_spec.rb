# frozen_string_literal: true

describe 'Content-Security-Policy header', type: :request do
  let(:directives) do
    response.headers['Content-Security-Policy'].split(';').to_h do
      name, *sources = it.split
      [name, sources]
    end
  end

  before { get '/contact' }

  it 'only lets a <base> tag point to us' do
    expect(directives['base-uri']).to eq(["'self'"])
  end

  it 'lets plugins fall back to default-src, data: included' do
    expect(directives).not_to have_key('object-src')
    expect(directives['default-src']).to include('data:')
  end
end
