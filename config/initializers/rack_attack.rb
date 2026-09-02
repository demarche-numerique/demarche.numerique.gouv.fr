# frozen_string_literal: true

class Rack::Attack
  # Note: limits use Rails.cache, which is global between our webservers.

  class << self
    def rack_attack_enabled?
      ENV['RACK_ATTACK_ENABLE'] == 'true'
    end
  end

  throttle('/users/sign_in/ip', limit: 25, period: 15.seconds) do |req|
    if req.path == '/users/sign_in' && req.post? && rack_attack_enabled?
      req.remote_ip
    end
  end

  throttle('stats/ip', limit: 5, period: 15.seconds) do |req|
    if req.path == '/stats' && rack_attack_enabled?
      req.remote_ip
    end
  end

  throttle('contact/ip', limit: 5, period: 30.seconds) do |req|
    if req.path == '/contact' && req.post? && rack_attack_enabled?
      req.remote_ip
    end
  end

  # Devise `lockable` n'incremente `failed_attempts` que lors d'une
  # authentification : `update_with_password` echappe au verrouillage.
  throttle('profil/mot-de-passe/ip', limit: 5, period: 60.seconds) do |req|
    if req.path == '/profil/mot-de-passe' && req.patch? && rack_attack_enabled?
      req.remote_ip
    end
  end

  # API prefill
  throttle('/api/public/v1/dossiers/ip', limit: 15, period: 15.seconds) do |req|
    if req.path == '/api/public/v1/dossiers' && req.post? && rack_attack_enabled?
      req.remote_ip
    end
  end

  throttle('referentiel_search_per_ip', limit: 60, period: 1.minute) do |req|
    req.remote_ip if req.post? && req.path.match?(/data_sources\/referentiel/) && rack_attack_enabled?
  end

  throttle('/api/v2/graphql', limit: ENV.fetch('RACK_ATTACK_GRAPHQL_LIMIT', 400).to_i, period: 1.minute) do |req|
    if req.post? && req.path.start_with?("/api/v2/graphql") && rack_attack_enabled?
      req.get_header('HTTP_AUTHORIZATION')
    end
  end

  Rack::Attack.safelist('allow trusted ips') do |req|
    IPService.ip_trusted?(req.remote_ip)
  end
end

Rack::Attack.throttled_response_retry_after_header = true
Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env['rack.attack.match_data']
  now = match_data[:epoch_time]
  reset = (now + (match_data[:period] - now % match_data[:period]))

  headers = {
    # 'RateLimit-Limit' => match_data[:limit].to_s,
    'RateLimit-Remaining' => '0',
    'RateLimit-Reset' => reset.to_s,
  }

  [
    429, headers, [
      "Calme toi, cowboy ! T'enchaines un peu trop les requêtes. Respire un peu réessaie dans un petit moment.\n" +
      "Calm down, cowboy! You're making too many requests. Take a breather and try again soon.\n",
    ],
  ]
end
