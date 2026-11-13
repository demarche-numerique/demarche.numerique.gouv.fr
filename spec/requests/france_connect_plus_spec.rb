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

  it 'explains why a procedure sends here' do
    get '/france_connect_plus/required'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Connexion FranceConnect+ requise')
    expect(response.body).to include('href="/france_connect_plus"')
  end

  it 'stays closed until enabled, configured or not' do
    ENV['FRANCE_CONNECT_PLUS_ENABLED'] = 'disabled'

    get '/france_connect_plus'

    expect(response).to redirect_to(new_user_session_path)
  end

  context 'when the identity is linked to an account' do
    let!(:user) { create(:user) }

    before { create(:france_connect_information, france_connect_particulier_id: 'fcp_sub', user:) }

    it 'signs in with FranceConnect+' do
      authenticate_with_france_connect_plus

      expect(controller.current_user).to eq(user)
      expect(UserSession.where(sessionable: user).sole.login_method).to eq('france_connect_plus')

      get profil_path
      expect(response.body).to include('via FranceConnect+')
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
      expect(UserSession.where(sessionable: controller.current_user).usable.sole.login_method).to eq('france_connect_plus')
    end

    it 'keeps FranceConnect+ through a merge by email link' do
      authenticate_with_france_connect_plus
      fci = FranceConnectInformation.find_by!(france_connect_particulier_id: 'fcp_sub')

      post france_connect_send_email_merge_request_path, params: { merge_token: fci.merge_token, email: 'other@example.org' }
      get france_connect_merge_using_email_link_path(email_merge_token: fci.reload.email_merge_token)

      expect(controller.current_user.email).to eq('other@example.org')
      expect(UserSession.where(sessionable: controller.current_user).usable.sole.login_method).to eq('france_connect_plus')
    end

    it 'voids an email link sent before a FranceConnect+ callback' do
      fci = create(:france_connect_information, france_connect_particulier_id: 'fcp_sub', requested_email: 'other@example.org')
      fci.create_merge_token!(login_method: :france_connect)
      email_merge_token = fci.create_email_merge_token!

      authenticate_with_france_connect_plus
      get france_connect_merge_using_email_link_path(email_merge_token:)

      expect(response).to redirect_to(root_path)
      expect(controller.current_user).to be_nil
      expect(fci.reload.user).to be_nil
    end

    it 'merges as FranceConnect once a FranceConnect callback follows' do
      authenticate_with_france_connect_plus
      fci = FranceConnectInformation.find_by!(france_connect_particulier_id: 'fcp_sub')

      allow(FranceConnectService).to receive_messages(
        enabled?: true,
        authorization_uri: ['https://fc.example.org/authorize', 'fc_state', 'fc_nonce'],
        find_or_retrieve_france_connect_information: [fci, 'fc_id_token']
      )
      get '/france_connect'
      get '/france_connect/callback', params: { code: 'a_code', state: 'fc_state' }
      post france_connect_merge_using_fc_email_path, params: { merge_token: fci.reload.merge_token }

      expect(controller.current_user.email).to eq('angela.dubois@example.org')
      expect(UserSession.where(sessionable: controller.current_user).usable.sole.login_method).to eq('france_connect')
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
    expect(UserSession.where(sessionable: user).usable.sole.login_method).to eq('france_connect')
  end
end
