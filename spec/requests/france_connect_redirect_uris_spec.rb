# frozen_string_literal: true

describe 'GET /france_connect/redirect_uris' do
  it 'lists the FranceConnect and FranceConnect+ callbacks of the dev domains' do
    host! 'dev.demarche.numerique.gouv.fr'

    get '/france_connect/redirect_uris'

    expect(response.parsed_body).to eq([
      'https://dev.demarches-simplifiees.fr/france_connect/callback',
      'https://dev.demarche.numerique.gouv.fr/france_connect/callback',
      'https://dev.demarches-simplifiees.fr/france_connect_plus/callback',
      'https://dev.demarche.numerique.gouv.fr/france_connect_plus/callback',
    ])
  end

  it 'lists the FranceConnect and FranceConnect+ callbacks of the production domains' do
    host! 'demarche.numerique.gouv.fr'

    get '/france_connect/redirect_uris'

    expect(response.parsed_body).to eq([
      'https://www.demarches-simplifiees.fr/france_connect/callback',
      'https://demarche.numerique.gouv.fr/france_connect/callback',
      'https://www.demarches-simplifiees.fr/france_connect_plus/callback',
      'https://demarche.numerique.gouv.fr/france_connect_plus/callback',
    ])
  end
end
