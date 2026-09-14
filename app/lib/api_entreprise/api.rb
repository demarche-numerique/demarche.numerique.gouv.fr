# frozen_string_literal: true

class APIEntreprise::API
  include Dry::Monads[:result]

  ETABLISSEMENT_RESOURCE_NAME = "v4/insee/sirene/etablissements/%{id}"
  EXTRAIT_KBIS_NAME = "v3/infogreffe/rcs/unites_legales/%{id}/extrait_kbis"
  TVA_NAME = "v3/dgfip/unites_legales/%{id}/numero_tva"
  EXERCICES_RESOURCE_NAME = "v3/dgfip/etablissements/%{id}/chiffres_affaires"
  RNA_RESOURCE_NAME = "v4/djepva/api-association/associations/open_data/%{id}"
  EFFECTIFS_RESOURCE_NAME = "v3/gip_mds/etablissements/%{id}/effectifs_mensuels"
  EFFECTIFS_ANNUELS_RESOURCE_NAME = "v3/gip_mds/unites_legales/%{id}/effectifs_annuels"
  ATTESTATION_SOCIALE_RESOURCE_NAME = "v4/urssaf/unites_legales/%{id}/attestation_vigilance"
  ATTESTATION_FISCALE_RESOURCE_NAME = "v4/dgfip/unites_legales/%{id}/attestation_fiscale"
  BILANS_BDF_RESOURCE_NAME = "v3/banque_de_france/unites_legales/%{id}/bilans"
  PRIVILEGES_RESOURCE_NAME = "privileges"

  # Rate limit pools (req/min) — keyed by ratelimit-limit header value.
  # Endpoints not listed here default to DEFAULT_POOL (250).
  POOL_BY_RESOURCE = {
    ATTESTATION_FISCALE_RESOURCE_NAME => 5,
    EFFECTIFS_RESOURCE_NAME => 50,
    EFFECTIFS_ANNUELS_RESOURCE_NAME => 50,
    ATTESTATION_SOCIALE_RESOURCE_NAME => 100,
  }.freeze
  DEFAULT_POOL = 250
  POOL_BY_PREFIX = POOL_BY_RESOURCE.transform_keys { |k| k.split('%').first }.freeze

  TIMEOUT = 20

  attr_reader :procedure
  attr_accessor :token
  attr_accessor :api_object

  def initialize(procedure_id = nil)
    return if procedure_id.blank?

    @procedure = Procedure.find(procedure_id)
    @token = @procedure.api_entreprise_token
  end

  def etablissement(siret)
    call_with_siret(ETABLISSEMENT_RESOURCE_NAME, siret)
  end

  def extrait_kbis(siren)
    call_with_siret(EXTRAIT_KBIS_NAME, siren)
  end

  def tva(siren)
    call_with_siret(TVA_NAME, siren)
  end

  def exercices(siret)
    call_with_siret(EXERCICES_RESOURCE_NAME, siret)
  end

  def rna(siret)
    call_with_siret(RNA_RESOURCE_NAME, siret)
  end

  def effectifs(siret, annee, mois)
    endpoint = [EFFECTIFS_RESOURCE_NAME, mois, "annee", annee].join('/')
    call_with_siret(endpoint, siret)
  end

  def effectifs_annuels(siren, annee)
    endpoint = [EFFECTIFS_ANNUELS_RESOURCE_NAME, annee].join('/')
    call_with_siret(endpoint, siren)
  end

  def attestation_sociale(siren)
    return Failure(type: :forbidden, code: 403, retryable: false, raw_response: nil) if !token.can_fetch_attestation_sociale?

    call_with_siret(ATTESTATION_SOCIALE_RESOURCE_NAME, siren)
  end

  def attestation_fiscale(siren, user_id)
    return Failure(type: :forbidden, code: 403, retryable: false, raw_response: nil) if !token.can_fetch_attestation_fiscale?

    call_with_siret(ATTESTATION_FISCALE_RESOURCE_NAME, siren, user_id: user_id)
  end

  def bilans_bdf(siren)
    return Failure(type: :forbidden, code: 403, retryable: false, raw_response: nil) if !token.can_fetch_bilans_bdf?

    call_with_siret(BILANS_BDF_RESOURCE_NAME, siren)
  end

  def privileges
    url = make_url(PRIVILEGES_RESOURCE_NAME)
    call(url)
  end

  private

  def recipient_for(siret_or_siren)
    service_siret = @procedure&.service && @procedure.service.siret.presence
    return service_siret if service_siret && !service_siret.starts_with?(siret_or_siren)
    ENV.fetch('API_ENTREPRISE_DEFAULT_SIRET')
  end

  def call_with_siret(resource_name, siret_or_siren, user_id: nil)
    url = make_url(resource_name, siret_or_siren)
    params = build_params(user_id, siret_or_siren)
    pool = pool_for(resource_name)

    call(url, params, pool:)
  end

  def call(url, params = nil, pool: DEFAULT_POOL)
    return Failure(type: :token_missing, code: 401, retryable: false, raw_response: nil) if token_missing?
    return Failure(type: :token_expired, code: 401, retryable: false, raw_response: nil) if token_expired?

    case client.call(url:, params:, headers: { 'Authorization' => "Bearer #{token.jwt_token}" }, timeout: TIMEOUT)
    in Success(body:, response:)
      APIEntreprise::RateLimiter.calibrate!(response, pool)
      Success(body)
    in Failure(type: :http, code:, error:)
      APIEntreprise::RateLimiter.calibrate!(error.try(:response), pool)
      classify_http_error(code, error.try(:response))
    in Failure(type:, code:, retryable:, error:)
      APIEntreprise::RateLimiter.calibrate!(error.try(:response), pool)
      Failure(type:, code:, retryable:, raw_response: error.try(:response))
    end
  end

  def client
    @client ||= API::Client.new
  end

  # API Entreprise documented HTTP codes: 200, 401, 403, 404, 409, 422, 429, 451, 502, 503, 504
  def classify_http_error(code, raw_response)
    case code
    when 401
      Failure(type: :unauthorized, code:, retryable: false, raw_response:)
    when 403
      Failure(type: :forbidden, code:, retryable: false, raw_response:)
    when 404
      Failure(type: :not_found, code:, retryable: false, raw_response:)
    when 409
      Failure(type: :conflict, code:, retryable: false, raw_response:)
    when 422
      Failure(type: :unprocessable, code:, retryable: false, raw_response:)
    when 429
      Failure(type: :rate_limited, code:, retryable: true, raw_response:)
    when 451
      Failure(type: :unavailable_for_legal_reasons, code:, retryable: false, raw_response:)
    when 500, 502, 503, 504
      if raw_response && service_unavailable?(raw_response)
        Failure(type: :service_unavailable, code:, retryable: true, raw_response:)
      else
        Failure(type: :server_error, code:, retryable: true, raw_response:)
      end
    else
      Rails.logger.warn("API Entreprise unexpected HTTP code: #{code}")
      Failure(type: :server_error, code:, retryable: true, raw_response:)
    end
  end

  SERVICE_UNAVAILABLE_ERRORS = ["01000", "01001", "01002", "02002", "03002", "03020", "28002", "29002", "31002", "34002"]
  SERVICE_UNAVAILABLE_CODES = [502, 503, 504]
  def service_unavailable?(raw_response)
    raw_response.code.in?(SERVICE_UNAVAILABLE_CODES) &&
      parse_response_errors(raw_response).any? { _1.is_a?(Hash) && _1[:code]&.in?(SERVICE_UNAVAILABLE_ERRORS) }
  end

  def parse_response_errors(raw_response)
    JSON.parse(raw_response.body, symbolize_names: true).fetch(:errors, [])
  rescue JSON::ParserError
    []
  end

  def make_url(resource_name, siret_or_siren = nil)
    [API_ENTREPRISE_URL, format(resource_name, id: siret_or_siren)].compact.join("/")
  end

  def build_params(user_id, siret_or_siren)
    params = base_params(siret_or_siren)

    params[:object] = if api_object.present?
      api_object
    elsif procedure.present?
      "procedure_id: #{procedure.id}"
    end

    params[:user_id] = user_id if user_id.present?

    params
  end

  def base_params(siret_or_siren)
    {
      context: APPLICATION_NAME,
      recipient: recipient_for(siret_or_siren),
      non_diffusables: true,
    }
  end

  def pool_for(resource_name)
    POOL_BY_PREFIX.each do |prefix, pool|
      return pool if resource_name.start_with?(prefix)
    end
    DEFAULT_POOL
  end

  def token_missing? = token.nil? || token.missing?
  def token_expired? = token.expired?
end
