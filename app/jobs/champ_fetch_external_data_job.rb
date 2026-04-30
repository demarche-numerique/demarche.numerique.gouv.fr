# frozen_string_literal: true

class ChampFetchExternalDataJob < ApplicationJob
  discard_on ActiveJob::DeserializationError
  queue_as :critical # ui feedback, asap

  retry_on RetryableFetchError, attempts: 3, wait: :polynomially_longer do |job, err|
    champ = job.arguments.first
    champ.external_data_error!

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
end
