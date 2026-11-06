# frozen_string_literal: true

module ProConnectHelpers
  # The login and the logout send the browser straight back to us, and the
  # code exchange returns this identity: no request leaves the test.
  def stub_pro_connect(email:)
    allow(ProConnectService).to receive(:enabled?).and_return(true)
    allow(ProConnectService).to receive(:authorization_uri)
      .and_return([pro_connect_callback_path(code: 'code', state: 'state'), 'state', 'nonce'])
    allow(ProConnectService).to receive(:authenticate)
      .and_return(ProConnectService::Authentication.new(
        user_info: { 'sub' => "sub-#{email}", 'email' => email, 'given_name' => 'Camille', 'usual_name' => 'Dupont' },
        id_token: 'id_token',
        amr: ['pwd', 'mfa'],
        acr: nil
      ))
    allow(ProConnectService).to receive(:logout_url).and_return(logout_path)
  end
end

RSpec.configure do |config|
  config.include ProConnectHelpers, type: :system
end
