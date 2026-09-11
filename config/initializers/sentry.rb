# frozen_string_literal: true

Sentry.init do |config|
  if ENV['http_proxy'].present?
    config.transport.proxy = ENV['http_proxy']
  end

  config.dsn = ENV.enabled?("SENTRY") ? ENV["SENTRY_DSN_RAILS"] : nil
  config.send_default_pii = false
  config.release = ApplicationVersion.current
  config.environment = ENV['SENTRY_CURRENT_ENV'] || Rails.env
  config.enabled_environments = ['production', ENV['SENTRY_CURRENT_ENV'].presence].compact
  config.breadcrumbs_logger = [:active_support_logger]
  config.app_dirs_pattern = %r{#{Regexp.escape(Rails.root.to_s)}/(app|bin|config|db|lib)/}

  config.traces_sampler = lambda do |sampling_context|
    # if this is the continuation of a trace, just use that decision (rate controlled by the caller)
    unless sampling_context[:parent_sampled].nil?
      next sampling_context[:parent_sampled]
    end

    if sampling_context.dig(:env, "REQUEST_METHOD") == "GET"
      0.001
    else
      0.01
    end
  end

  config.excluded_exceptions += ['APIEntreprise::Job::ProviderDownError']

  # Lambda so the app constant is resolved at send time, not at boot.
  config.before_send = -> (event, hint) { SentryFingerprint.call(event, hint) }

  # Note: sentry-ruby's :graphql patch is intentionally NOT enabled here.
  # It attaches GraphQL::Tracing::SentryTrace which wraps every field resolution
  # with a span + clock_gettime calls. On large API V2 responses (tens of
  # thousands of fields) this adds measurable request latency (cf. Skylight's
  # NotificationsTrace probe, disabled in config/application.rb for the same
  # reason). If enabling later via `config.enabled_patches << :graphql`, plan
  # for a per-field-off custom trace (only execute_multiplex/execute_query).
end
