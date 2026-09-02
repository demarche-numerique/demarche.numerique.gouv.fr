# frozen_string_literal: true

class APIParticulier::API
  include Dry::Monads[:result]

  TIMEOUT = 20

  def initialize(procedure, type_champ)
    @procedure = procedure
    @token = procedure.api_particulier_token
    @type_champ = type_champ
  end

  def call_with_fci(fci)
    # Un jeton absent, illisible ou expiré sera refusé par API Particulier : on
    # s'épargne l'appel, et la construction des paramètres. L'administrateur est
    # prévenu par Cron::SendAPIParticulierTokenExpirationNoticeJob.
    return Failure(retryable: false, error: StandardError.new("API Particulier: token_unusable"), code: :token_unusable) if @token.unusable?

    url = [API_PARTICULIER_URL, resource].join("/")

    params = build_params(fci)

    call(url, params)
  end

  private

  def resource
    TypesDeChamp::FranceConnectTypeDeChamp.config_for(@type_champ)[:resource]
  end

  def build_params(fci)
    {
      recipient: recipient_for_procedure,
      **user_params_for(fci),
    }
  end

  def recipient_for_procedure
    @procedure.service&.siret.presence || ENV.fetch('API_PARTICULIER_DEFAULT_SIRET')
  end

  def user_params_for(fci)
    gender_for_api = fci.gender == 'female' ? 'F' : 'M'

    given_name_for_api = fci.given_name.split(" ")

    {
      codeCogInseePaysNaissance: fci.birthcountry,
      codeCogInseeCommuneNaissance: fci.birthplace,
      sexeEtatCivil: gender_for_api,
      nomNaissance: fci.family_name,
      "prenoms[]" => given_name_for_api,
      anneeDateNaissance: fci.birthdate.year.to_s,
      moisDateNaissance: fci.birthdate.month.to_s,
      jourDateNaissance: fci.birthdate.day.to_s,
    }
  end

  def call(url, params)
    response = Typhoeus.get(url,
      headers: { Authorization: "Bearer #{@token.jwt_token}" },
      params: params,
      params_encoding: :multi,
      timeout: TIMEOUT)

    body = parse_response_body(response.body)

    if response.success?
      if !schema.valid?(body)
        Sentry.capture_message(
          "Invalid API schema response",
          extra: {
            url: url,
            response_keys: body.is_a?(Hash) ? body.keys : body.class.name,
            schema_errors: schema.validate(body).map { |e| e["error"] }.join("\n"),
          }
        )

        return Failure(retryable: false, error: StandardError.new("API Particulier: invalid_schema"), code: :invalid_schema)
      end

      Success(body[:data])
    else
      # Le corps entier donnait autant de groupes Sentry distincts que de
      # dossiers, et porte des données personnelles. Le code d'erreur métier
      # suffit à identifier la cause.
      Failure(retryable: false, error: StandardError.new(error_message(response, body)), code: response.code)
    end
  end

  def error_message(response, body)
    errors = body[:errors] if body.is_a?(Hash)
    business_code = errors.first[:code] if errors.is_a?(Array) && errors.first.is_a?(Hash)

    ["API Particulier: #{response.code}", business_code].compact.join(' ')
  end

  def parse_response_body(body)
    JSON.parse(body, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  def schema
    JSONSchemer.schema(
      Rails.root.join(
        TypesDeChamp::FranceConnectTypeDeChamp.config_for(@type_champ)[:schema]
      )
    )
  end
end
