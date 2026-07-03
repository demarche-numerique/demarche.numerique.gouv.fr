# frozen_string_literal: true

class ChampFetchExternalDataJob < ApplicationJob
  discard_on ActiveJob::DeserializationError
  queue_as :critical # ui feedback, asap

  retry_on RetryableFetchError, attempts: 3, wait: :polynomially_longer do |job, err|
    champ_data = job.arguments.first
    champ_data.external_data_error!

    # Don't raise, otherwise it will pop forever as "working" queue without doing anything
    Sentry.capture_exception(err.cause)
  end

  def perform(champ_data, external_id)
    return if champ_data.external_id != external_id
    return if !champ_data.waiting_for_job?

    champ = Champ.from_data(champ_data)
    # Orphaned champ data: the type de champ left the dossier revision.
    return if champ.nil?

    Sentry.set_tags(champ: champ_data.id)
    Sentry.set_extras(external_id:)

    champ.fetch!
  end
end
