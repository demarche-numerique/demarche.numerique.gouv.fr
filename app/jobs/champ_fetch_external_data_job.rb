# frozen_string_literal: true

class ChampFetchExternalDataJob < ApplicationJob
  discard_on ActiveJob::DeserializationError
  queue_as :critical # ui feedback, asap

  retry_on RetryableFetchError, attempts: 3, wait: :polynomially_longer do |job, err|
    job.settle_exhausted_champ

    # Don't raise, otherwise it will pop forever as "working" queue without doing anything
    Sentry.capture_exception(err.cause)
  end

  def perform(champ, external_id)
    return if champ.external_id != external_id
    return if !champ.waiting_for_job?

    Sentry.set_tags(champ: champ.id)
    Sentry.set_extras(external_id:)

    champ.fetch!
  end

  def settle_exhausted_champ
    champ, external_id = arguments
    return if champ.external_id != external_id
    return if !champ.waiting_for_job?

    champ.handle_exhausted_external_data_retries!
  rescue StandardError => e
    Sentry.capture_exception(e)
    champ.external_data_error! if champ&.may_external_data_error?
  end
end
