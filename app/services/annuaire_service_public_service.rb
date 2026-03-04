# frozen_string_literal: true

class AnnuaireServicePublicService
  include Dry::Monads[:result]

  def call(siret:)
    result = API::Client.new.call(url: url(siret), schema:, timeout: 1.second)

    case result
    in Success(body:)
      result = body[:results].first

      if result.present?
        Success(
          result.slice(:nom, :adresse, :adresse_courriel).merge(
            telephone: maybe_json_parse(result[:telephone]),
            plage_ouverture: maybe_json_parse(result[:plage_ouverture]),
            adresse: maybe_json_parse(result[:adresse])
          )
        )
      else
        Failure(API::Client::Error[:not_found, 404, false, "No result found for this SIRET."])
      end
    in Failure(code:, error:) if code.in?(401..403)
      Sentry.capture_message("#{self.class.name}: #{error} code: #{code}", extra: { siret: })
      Failure(API::Client::Error[:unauthorized, code, false, error])
    in Failure(type: :schema, code:, error:)
      error.errors[0].first
      Sentry.capture_exception(error, extra: { siret:, code: })

      Failure(API::Client::Error[:schema, code, false, error])
    else
      result
    end
  end

  private

  def schema
    JSONSchemer.schema(Rails.root.join('app/schemas/service-public.json'))
  end

  def url(siret)
    "https://api-lannuaire.service-public.fr/api/explore/v2.1/catalog/datasets/api-lannuaire-administration/records?where=siret:#{siret}"
  end

  def maybe_json_parse(value)
    return nil if value.blank?

    JSON.parse(value)
  end
end
