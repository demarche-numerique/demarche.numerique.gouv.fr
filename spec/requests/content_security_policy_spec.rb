# frozen_string_literal: true

describe 'Content-Security-Policy header', type: :request do
  let(:directives) do
    response.headers['Content-Security-Policy'].split(';').to_h do
      name, *sources = it.split
      [name, sources]
    end
  end

  before { get '/contact' }

  it 'does not restrict where a <base> tag can point' do
    expect(directives).not_to have_key('base-uri')
  end
end
