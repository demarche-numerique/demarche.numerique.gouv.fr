# frozen_string_literal: true

# Orchestration of async external data fetching, on the projected champ.
# The state machine itself (external_state transitions) lives on ChampData;
# this concern drives it and applies the fetched data through the champ
# persistence facade, so per-type behavior (fetch_external_data,
# update_external_data!, after_reset_external_data overrides) stays on the
# domain model.
#
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
module ChampExternalDataConcern
  extend ActiveSupport::Concern

  include Dry::Monads[:result]

  def external_state = consistent_data&.external_state

  # the enum maps idle to a NULL column value, but the enum reader still
  # returns 'idle' on champ data
  def idle? = external_state.nil? || external_state == 'idle'
  def waiting_for_job? = external_state == ChampData.external_states.fetch(:waiting_for_job)
  def fetching? = external_state == ChampData.external_states.fetch(:fetching)
  def fetched? = external_state == ChampData.external_states.fetch(:fetched)
  def external_error? = external_state == ChampData.external_states.fetch(:external_error)

  def pending? = waiting_for_job? || fetching?
  def done? = fetched? || external_error?
  def external_data_not_found? = external_error? && fetch_external_data_exceptions.last.not_found?

  def fetch_external_data_exceptions
    consistent_data&.fetch_external_data_exceptions || []
  end

  def has_async_external_data? = false

  def external_data_needed_for_validation? = has_async_external_data?

  def may_fetch_later? = champ_data.present? && ready_for_external_call? && champ_data.may_fetch_later?
  def may_fetch? = champ_data.present? && champ_data.may_fetch?

  def fetch_later!(wait: nil)
    # The guard used to live on the AASM transition; external_id is domain
    # data, so it is enforced here.
    if !ready_for_external_call?
      raise AASM::InvalidTransition.new(champ_data!, :fetch_later, :default)
    end

    champ_data!.fetch_later!
    fetch_external_data_later(wait:)
  end

  # Non persisting variant: the caller saves the champ itself (see
  # Attachment::PieceJustificativeService). The job double-checks the persisted
  # state, so a rolled back save makes the enqueued job a no-op.
  def fetch_later(wait: nil)
    return false if !ready_for_external_call?

    champ_data!.fetch_later
    fetch_external_data_later(wait:)
  end

  def fetch!
    champ_data!.fetch!
    fetch_and_handle_result
  end

  def reset_external_data!(opts = {})
    champ_data!.reset_external_data!
    after_reset_external_data(opts)
  end

  delegate :external_data_fetched!, :external_data_error!, :retry!, to: :champ_data!

  private

  def ready_for_external_call? = external_id.present?

  def fetch_external_data_later(wait: nil)
    champ_data = self.champ_data
    external_id = self.external_id
    ActiveRecord.after_all_transactions_commit do
      ChampFetchExternalDataJob.set(wait:).perform_later(champ_data, external_id)
    end
  end

  # it should only be called after the fetch! transition
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
        save_external_error(error, code)
        retry!
        raise RetryableFetchError.new(error)
      in Failure(retryable: false, error:, code:)
        save_external_error(error, code)
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

  def save_external_error(error, code)
    exceptions = fetch_external_data_exceptions.dup
    exceptions << ExternalDataException.new(error: error.inspect, code:)
    update_columns(fetch_external_data_exceptions: exceptions)
  end

  def after_reset_external_data(opts = {})
    update(opts.merge(data: nil, value_json: nil, fetch_external_data_exceptions: []))
  end
end
