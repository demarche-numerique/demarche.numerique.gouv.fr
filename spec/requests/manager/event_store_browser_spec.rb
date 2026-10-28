# frozen_string_literal: true

describe 'Event store browser', type: :request do
  let(:super_admin) { create(:super_admin, otp_required_for_login: true) }

  before { login_as super_admin, scope: :super_admin }

  it 'serves the browser to an enrolled super admin' do
    get '/manager/event_store'
    expect(response).to redirect_to('/manager/event_store/streams/all')

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('RubyEventStore::Browser')
  end
end
