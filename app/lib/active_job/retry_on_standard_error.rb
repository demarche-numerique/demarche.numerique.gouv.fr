# frozen_string_literal: true

module ActiveJob::RetryOnStandardError
  extend ActiveSupport::Concern

  MAX_ATTEMPTS_JOBS = ENV.fetch("MAX_ATTEMPTS_JOBS", 25).to_i

  class_methods do
    # Opt out of Active Job's retry_on StandardError and rely on Sidekiq's
    # native retry mechanism instead. Useful for long-running jobs where
    #
    # retry: number of Sidekiq retries (polynomial backoff: 25 retries span
    # about three weeks).
    #
    # report_after_attempts: when set, sentry-sidekiq only reports the error
    # once the job reaches that attempt number (see Sentry::Sidekiq::ErrorHandler
    # reading the `attempt_threshold` job option). Keeps transient external-API
    # failures out of Sentry until they persist across several retries.
    def use_sidekiq_retry(retry: MAX_ATTEMPTS_JOBS, report_after_attempts: nil)
      self.rescue_handlers = rescue_handlers.reject { |klass_name, _| klass_name == "StandardError" }
      sidekiq_options retry: binding.local_variable_get(:retry)
      sidekiq_options attempt_threshold: report_after_attempts if report_after_attempts
    end
  end

  included do
    # Disable Sidekiq retries so only Active Job's retry_on applies.
    # Without this, Sidekiq would retry the job after Active Job exhausts retries,
    # causing many more executions (activejob retries × Sidekiq default 25 retries).
    # WARN: because sentry-sidekiq overrides, exceptions will not pop automatically in sentry.
    sidekiq_options retry: false

    retry_on StandardError, attempts: MAX_ATTEMPTS_JOBS, wait: :polynomially_longer
  end
end
