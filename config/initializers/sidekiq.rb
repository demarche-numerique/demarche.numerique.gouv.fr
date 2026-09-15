# frozen_string_literal: true

SIDEKIQ_ENABLED = ENV.key?('REDIS_SIDEKIQ_SENTINELS') || ENV.key?('REDIS_URL') || ENV['RAILS_QUEUE_ADAPTER'] == 'sidekiq'

return if !SIDEKIQ_ENABLED

sidekiq_redis = if ENV.key?('REDIS_SIDEKIQ_SENTINELS')
  name = ENV.fetch('REDIS_SIDEKIQ_MASTER')
  username = ENV.fetch('REDIS_SIDEKIQ_USERNAME')
  password = ENV.fetch('REDIS_SIDEKIQ_PASSWORD')
  sentinels = ENV.fetch('REDIS_SIDEKIQ_SENTINELS')
    .split(',')
    .map { URI.parse(_1) }
    .map { { host: _1.host, port: _1.port, username:, password: } }

  {
    name:,
    sentinels:,
    username:,
    password:,
    role: :master,
  }
else
  {} # default config from REDIS_URL
end

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis
  if ENV['PROMETHEUS_EXPORTER_ENABLED'] == 'enabled'
    Yabeda.configure!
    Yabeda::Prometheus::Exporter.start_metrics_server!
  end

  if ENV['SKIP_RELIABLE_FETCH'].blank?
    # Load-bearing: since 0.12.1 the fetcher falls back to capsule.mode when
    # :strict is unset, and our weighted queues make that mode :weighted.
    # Removing this line would silently swap strict priority for weighted order.
    config[:strict] = true

    Sidekiq::ReliableFetch.setup_reliable_fetch!(config)
  end
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_redis
end
