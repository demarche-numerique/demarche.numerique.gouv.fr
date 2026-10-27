# frozen_string_literal: true

module APIEntreprise::HealthChecker
  PING_BASE_URL = "#{API_ENTREPRISE_URL}/ping"
  CACHE_KEY_PREFIX = "api_entreprise:health"
  CACHE_TTL = 5.minutes

  PROVIDERS = {
    insee_sirene: 'insee/sirene',
    infogreffe_rcs: 'infogreffe/rcs',
    dgfip_numero_tva: 'dgfip/numero_tva',
    djepva_association: 'djepva/api-association',
    dgfip_chiffre_affaires: 'dgfip/chiffre_affaires',
    dgfip_attestation_fiscale: 'dgfip/attestation_fiscale',
    gip_mds_effectifs: 'gip_mds/effectifs',
    urssaf_attestation_sociale: 'urssaf/attestation_sociale',
    banque_de_france_bilans: 'banque_de_france/bilans',
  }.freeze

  # ok = provider works correctly
  # unknown = insufficient data to determine status (HTTP 200, fail-open by design)
  UP_STATUSES = %w[ok unknown].freeze

  def self.provider_up?(provider)
    ping_key = provider.is_a?(Symbol) ? PROVIDERS.fetch(provider) : provider
    status = cached_status(ping_key)
    return true if status.nil? # fail-open: cache empty or Redis down
    status.in?(UP_STATUSES)
  rescue Redis::BaseError
    true
  end

  def self.refresh_all!
    hydra = Typhoeus::Hydra.new
    PROVIDERS.each_value do |key|
      request = Typhoeus::Request.new("#{PING_BASE_URL}/#{key}", timeout: 5)
      request.on_complete { |response| store_response(key, response) }
      hydra.queue(request)
    end
    hydra.run
  end

  def self.cached_status(ping_key)
    Kredis.redis.get(cache_key(ping_key))
  end

  def self.cache_key(ping_key)
    "#{CACHE_KEY_PREFIX}:#{ping_key}"
  end

  def self.store_response(ping_key, response)
    status = parse_status(response)

    Kredis.redis.set(cache_key(ping_key), status, ex: CACHE_TTL.to_i)
    status
  rescue => e
    Rails.logger.error("HealthChecker: refresh failed for #{ping_key}: #{e.class} #{e.message}")
    Sentry.capture_exception(e)
    nil
  end

  # Anything outside UP_STATUSES marks the provider as down, so an unusable
  # response falls back to a synthetic down status rather than raising: the
  # circuit breaker reschedules the jobs. Fail-safe: jobs only retry.
  def self.parse_status(response)
    if response.timed_out? || response.code.zero? || response.body.blank?
      # No usable response (timeout, connection error): on_complete is still
      # invoked by Typhoeus with an empty body. The same outage shows up
      # sometimes as a 502 bad_gateway, sometimes as a timeout.
      'no_response'
    else
      # An outage is usually reported as JSON ({"status": "bad_gateway"}), but
      # /ping also serves plain HTML error pages, and JSON without any status
      # ({} on a 404). Both must read as down instead of flooding Sentry.
      JSON.parse(response.body)['status'] || "http_#{response.code}"
    end
  rescue JSON::ParserError
    "http_#{response.code}"
  end
end
