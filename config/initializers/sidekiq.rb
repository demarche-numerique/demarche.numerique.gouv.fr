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
    # Image decoding runs in a subprocess now, so it no longer shows in this process's
    # RSS, and nothing in `top` outlives the decode long enough to be graphed. libvips
    # reports its own peak (--vips-leak); SandboxedVips hands it over here, where it
    # becomes the history needed to size the memory limit a cgroup would enforce.
    #
    # Declared and subscribed inside configure_server on purpose: decoding only ever
    # happens in a job, and the web process has no business carrying Yabeda.
    Yabeda.configure do
      group :decoder do
        histogram :peak_memory_bytes,
                  comment: "Peak memory a sandboxed image decoder allocated",
                  unit: :bytes,
                  buckets: [1, 8, 32, 128, 256, 512, 1024, 2048, 4096].map(&:megabytes)

        histogram :duration_seconds,
                  comment: "Wall time a sandboxed image decoder ran for",
                  unit: :seconds,
                  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60]
      end
    end

    Yabeda.configure!
    Yabeda::Prometheus::Exporter.start_metrics_server!

    ActiveSupport::Notifications.subscribe("decode.sandbox") do |event|
      tags = { decoder: event.payload[:decoder] }
      peak_memory = event.payload[:peak_memory]

      Yabeda.decoder.duration_seconds.measure(tags, event.duration / 1000)
      Yabeda.decoder.peak_memory_bytes.measure(tags, peak_memory) if peak_memory
    end
  end

  if ENV['SKIP_RELIABLE_FETCH'].blank?
    config[:strict] = true

    Sidekiq::ReliableFetch.setup_reliable_fetch!(config)
  end
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_redis
end
