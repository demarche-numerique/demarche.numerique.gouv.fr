# frozen_string_literal: true

describe 'the legacy /graphql playground URL', type: :request do
  it 'redirects to the documentation explaining how to use a GraphQL client' do
    get '/graphql'

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to(API_GRAPHQL_CLIENT_DOC_URL)
  end

  it 'does not redirect POST requests, so a misconfigured API client is not served HTML' do
    post '/graphql'

    expect(response).to have_http_status(:not_found)
  end

  it 'keeps serving the schema documentation' do
    get '/graphql/schema'

    expect(response).to redirect_to('/graphql/schema/index.html')
  end
end
