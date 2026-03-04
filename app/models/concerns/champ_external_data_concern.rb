# frozen_string_literal: true

module ChampExternalDataConcern
  extend ActiveSupport::Concern

  include Dry::Monads[:result]

  # A champ is updated, a reset and fetch later event is triggered
  # from the controller
  # idle -> waiting_for_job
  # A ChampFetchExternalDataJob is processed, the fetch event is triggered
  # waiting_for_job -> fetching
  # if an retryable error occurs, the retry event is triggered and the job is re-enqueued
  # fetching -> waiting_for_job
  # if a non-retryable error occurs, the external_data_error event is triggered
  # fetching -> external_error
  # if the data is fetched successfully, the external_data_fetched event is triggered
  # fetching -> fetched

  included do
    include AASM
    attribute :fetch_external_data_exceptions, :external_data_exception, array: true

    # useful to serialize idle as nil
    # otherwise, all the champ are mark as dirty and saved on first dossier.save
    enum :external_state, {
      idle: nil, # initial state
      waiting_for_job: 'waiting_for_job',
      fetching: 'fetching',
      fetched: 'fetched',
      external_error: 'external_error',
    }

    aasm column: :external_state, enum: true do
      state :idle, initial: true
      state :waiting_for_job
      state :fetching
      state :fetched
      state :external_error

      event :fetch_later, after_commit: :fetch_external_data_later do
        transitions from: :idle, to: :waiting_for_job, guard: :ready_for_external_call?
      end

      event :fetch, after_commit: :fetch_and_handle_result do
        transitions from: [:idle, :waiting_for_job], to: :fetching, guard: :ready_for_external_call?
      end

      event :external_data_fetched do
        transitions from: [:fetching], to: :fetched
      end

      event :external_data_error do
        transitions from: [:waiting_for_job, :fetching], to: :external_error
      end

      event :retry do
        transitions from: [:fetching], to: :waiting_for_job
      end

      event :reset_external_data, after: :after_reset_external_data do
        transitions from: [:idle, :waiting_for_job, :fetching, :fetched, :external_error], to: :idle
      end
    end
  end

  def pending? = waiting_for_job? || fetching?
  def done? = fetched? || external_error?

  def has_async_external_data? = false

  def external_data_needed_for_validation? = has_async_external_data?

  private

  def ready_for_external_call? = external_id.present?

  def fetch_external_data_later(wait: nil)
    ChampFetchExternalDataJob.set(wait:).perform_later(self, external_id)
  end

  # it should only be called after fetch! event callback
  def fetch_and_handle_result
    fetch_external_data.then { handle_result(it) }
  end

  def fetch_external_data
    raise NotImplemented.new(:fetch_external_data)
  end

  def handle_result(result)
    if result.is_a?(Dry::Monads::Result)
      case result
      in Success(hash)
        update_external_data!(hash)
        external_data_fetched!
      in Failure(retryable: true, error:, code:)
        save_external_exception(error, code)
        retry!
        raise RetryableFetchError.new(error)
      in Failure(retryable: false, error:, code:)
        save_external_exception(error, code)
        Sentry.capture_exception(error) if code != 404
        external_data_error!
      end
    elsif result.present?
      update_external_data!(data: result)
      external_data_fetched!
    end
  end

  def update_external_data!(hash)
    update!(hash.merge(fetch_external_data_exceptions: []))
  end

  def save_external_exception(error, code)
    exceptions = fetch_external_data_exceptions || []
    exceptions << ExternalDataException.new(error: error.inspect, code:)
    update_columns(fetch_external_data_exceptions: exceptions)
  end

  def after_reset_external_data(opts = {})
    update(opts.merge(data: nil, value_json: nil, fetch_external_data_exceptions: []))
  end
end
