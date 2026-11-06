# frozen_string_literal: true

# Cached, so the provider is discovered once per example
describe 'FranceConnect+ authentication', :caching do
  around { |example| with_france_connect_plus_env { example.run } }

  let(:user_info) do
    {
      sub: 'fcp_sub',
      given_name: 'Angela Claire Louise',
      family_name: 'DUBOIS',
      birthdate: '1962-08-24',
      gender: 'female',
      birthplace: '75107',
      birthcountry: '99100',
      email: 'angela.dubois@example.org',
    }
  end

  before { stub_france_connect_plus_discovery }

  def authenticate_with_france_connect_plus
    get '/france_connect_plus'
    authorize_params = Rack::Utils.parse_query(URI(response.location).query)

    stub_france_connect_plus_tokens(id_token: france_connect_plus_id_token(nonce: authorize_params.fetch('nonce')), user_info:)

    get '/france_connect_plus/callback', params: { code: 'a_code', state: authorize_params.fetch('state') }
  end

  it 'redirects to FranceConnect+ for the eIDAS substantiel level' do
    get '/france_connect_plus'

    expect(response.location).to start_with("#{FranceConnectPlusHelpers::ISSUER}/authorize?")
    expect(Rack::Utils.parse_query(URI(response.location).query)).to include('acr_values' => 'eidas2')
  end

  context 'when the identity is linked to an account' do
    let!(:user) { create(:user) }

    before { create(:france_connect_information, france_connect_particulier_id: 'fcp_sub', user:) }

    it 'signs in with FranceConnect+' do
      authenticate_with_france_connect_plus

      expect(controller.current_user).to eq(user)
      expect(controller.send(:logged_in_with_france_connect_plus?)).to be(true)
    end

    it 'signs out of FranceConnect+ too' do
      authenticate_with_france_connect_plus

      delete destroy_user_session_path

      logout_params = Rack::Utils.parse_query(URI(response.location).query)
      expect(response.location).to start_with("#{FranceConnectPlusHelpers::ISSUER}/session/end?")
      # FranceConnect+ finds the session to close from the decrypted id token
      expect(JSON::JWT.decode(logout_params.fetch('id_token_hint'), FranceConnectPlusHelpers::SIGNING_PUBLIC_KEY)['sub']).to eq('fcp_sub')
    end
  end

  context 'when the identity is linked to no account yet' do
    it 'keeps FranceConnect+ through the account creation' do
      authenticate_with_france_connect_plus
      expect(response).to render_template('france_connect/choose_email')

      merge_token = FranceConnectInformation.find_by!(france_connect_particulier_id: 'fcp_sub').merge_token
      post france_connect_merge_using_fc_email_path, params: { merge_token: }

      expect(controller.current_user.email).to eq('angela.dubois@example.org')
      expect(controller.send(:logged_in_with_france_connect_plus?)).to be(true)
    end
  end

  it 'drops FranceConnect+ on a FranceConnect sign in' do
    user = create(:user)
    fci = create(:france_connect_information, france_connect_particulier_id: 'fcp_sub', user:)
    authenticate_with_france_connect_plus

    allow(FranceConnectService).to receive_messages(
      enabled?: true,
      authorization_uri: ['https://fc.example.org/authorize', 'fc_state', 'fc_nonce'],
      find_or_retrieve_france_connect_information: [fci, 'fc_id_token']
    )
    get '/france_connect'
    get '/france_connect/callback', params: { code: 'a_code', state: 'fc_state' }

    expect(controller.current_user).to eq(user)
    expect(controller.send(:logged_in_with_france_connect_plus?)).to be(false)
  end
end
