# frozen_string_literal: true

class Cron::RetryDegradedExternalDataJob < Cron::CronJob
  # They all went degraded within the same outage: spread them out, the champ
  # queue has no rate limiter of its own.
  SPREAD_OVER = 20.minutes

  # An outage leaves far more degraded champs than one run can replay without
  # flooding the pool. What is left over waits for the next run.
  BATCH_SIZE = 2_000

  class_attribute :champ_class, :health_provider
  class_attribute :spread_over, default: SPREAD_OVER
  class_attribute :batch_size, default: BATCH_SIZE

  # Abstract class: keeps `rake jobs:schedule` from registering this base,
  # which has no schedule_expression, in Sidekiq Cron.
  def self.schedulable?
    schedule_expression.present? && super
  end

  def perform(*args)
    return if !provider_ready?

    retryable_batch.find_each do |record|
      record.fix_degraded!(wait: rand(0..spread_over)) if record.may_fix_degraded?
    end
  end

  private

  def provider_ready?
    APIEntreprise::HealthChecker.provider_up?(health_provider) &&
      !APIEntreprise::RateLimiter.throttled?(APIEntreprise::API::DEFAULT_POOL)
  end

  def retryable_batch
    degraded_records
      .merge(replayable_procedures)
      .limit(batch_size)
      .preload(dossier: :procedure)
  end

  # Whatever blocks the token blocks every retry it covers, so it is filtered
  # here rather than discovered champ by champ once the batch is already full.
  def replayable_procedures = Procedure.with_usable_api_entreprise_token

  def degraded_records
    champ_class
      .degraded
      .joins(dossier: :procedure)
      .merge(Procedure.kept)
      .where(champs: { stream: Dossier::NON_HISTORY_STREAMS })
      .where(dossiers: { hidden_by_administration_at: nil, hidden_by_expired_at: nil })
  end
end
