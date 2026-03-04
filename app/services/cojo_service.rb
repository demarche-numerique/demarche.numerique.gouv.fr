# frozen_string_literal: true

class COJOService
  include Dry::Monads[:result]

  def call(accreditation_number:, accreditation_birthdate:)
    result = API::Client.new.(url:,
      json: {
        accreditationNumber: accreditation_number.to_i,
        birthdate: accreditation_birthdate&.strftime('%d/%m/%Y'),
      },
      authorization_token:,
      schema:,
      method: :post)

    case result
    in Success(body:)
      accreditation_success = body[:individualExistance] == 'Yes'
      Success({
        accreditation_success:,
        accreditation_first_name: accreditation_success ? body[:firstName] : nil,
        accreditation_last_name: accreditation_success ? body[:lastName] : nil,
      })
    in Failure(code:, error:) if code.in?(401..403)
      Failure(API::Client::Error[:unauthorized, code, false, error])
    else
      result
    end
  end

  private

  def schema
    JSONSchemer.schema(Rails.root.join('app/schemas/accreditation-cojo.json'))
  end

  def url
    "#{API_COJO_URL}/api/accreditation"
  end

  def authorization_token
    rsa_private_key&.then { JWT.encode(jwt_payload, _1, 'RS256') }
  end

  def jwt_payload
    {
      iss: Current.application_name,
      iat: Time.zone.now.to_i,
      exp: 1.hour.from_now.to_i,
    }
  end

  def rsa_private_key
    if ENV['COJO_JWT_RSA_PRIVATE_KEY'].present?
      OpenSSL::PKey::RSA.new(ENV['COJO_JWT_RSA_PRIVATE_KEY'])
    end
  end
end
