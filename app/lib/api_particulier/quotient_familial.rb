# frozen_string_literal: true

class APIParticulier::QuotientFamilial
  include Dry::Monads[:result]

  QUOTIENT_FAMILIAL = "v3/dss/quotient_familial/identite"
  TIMEOUT = 20

  def initialize(procedure)
    @procedure = procedure
    @token = procedure.api_particulier_token
  end

  def quotient_familial(fci)
    call_with_fci(QUOTIENT_FAMILIAL, fci)
  end

  private

  def call_with_fci(resource_name, fci)
    url = [API_PARTICULIER_URL, resource_name].join("/")

    params = build_params(fci)

    call(url, params)
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
      headers: { Authorization: "Bearer #{@token}" },
      params: params,
      params_encoding: :multi,
      timeout: TIMEOUT)

    body = JSON.parse(response.body, symbolize_names: true)

    if response.success?
      return Failure(retryable: false, reason: StandardError.new("Not retryable: invalid schema"), code: :invalid_schema) if !schema.valid?(body[:data])

      Success({ value_json: body[:data] })
    else
      Failure(retryable: false, reason: StandardError.new("Not retryable: #{body.dig(:errors)}"), code: response.code)
    end
  end

  def schema
    JSONSchemer.schema(Rails.root.join('app/schemas/quotient-familial.json'))
  end
end
