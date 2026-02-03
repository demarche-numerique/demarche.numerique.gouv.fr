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

    # transaction_context is the transaction object in hash form
    # keep in mind that sampling happens right after the transaction is initialized
    # for example, at the beginning of the request
    transaction_context = sampling_context[:transaction_context]

    # transaction_context helps you sample transactions with more sophistication
    # for example, you can provide different sample rates based on the operation or name
    case transaction_context[:op]
    when /delayed_job/
      contexts = Sentry.get_current_scope.contexts
      job_class = contexts.dig(:"Active-Job", :job_class)
      attempts = contexts.dig(:"Delayed-Job", :attempts)
      max_attempts = job_class.safe_constantize&.new&.max_attempts rescue 25

      # Don't trace on all attempts
      [0, 2, 5, 10, 20, max_attempts].include?(attempts)
    else # rails requests
      if sampling_context.dig(:env, "REQUEST_METHOD") == "GET"
        0.001
      else
        0.01
      end
    end
  end

  # config.excluded_exceptions += []
  config.delayed_job.report_after_job_retries = false # don't wait for all attempts before reporting

  config.rails.active_job_report_on_retry_error = true # https://github.com/getsentry/sentry-ruby/pull/2617
end
