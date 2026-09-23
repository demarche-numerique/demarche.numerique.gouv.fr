# frozen_string_literal: true

RSpec.shared_context "with a failing RDV Service Public token refresh" do
  let(:oauth_error_code) { 'invalid_grant' }

  before do
    access_token = instance_double(OAuth2::AccessToken)
    allow(access_token).to receive(:refresh!).and_raise(OAuth2::Error.new({ 'error' => oauth_error_code }))

    allow(OAuth2::Client).to receive(:new).and_return(instance_double(OAuth2::Client))
    allow(OAuth2::AccessToken).to receive(:new).and_return(access_token)
  end
end
