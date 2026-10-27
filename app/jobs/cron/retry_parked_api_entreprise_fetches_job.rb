# frozen_string_literal: true

class Cron::RetryParkedAPIEntrepriseFetchesJob < Cron::CronJob
  self.schedule_expression = "every 2 hours at minute 45"

  KEPT_FOR = 1.month
  REPLAYED_EVERY = 2.hours
  RETRIED_DAILY_EVERY = 1.day
  SPREAD_OVER = 110.minutes
  LOST_AFTER = 1.day
  ENQUEUED_TOGETHER = 1_000
  SHARE_OF_POOL_PERCENT = 20

  def self.batch_size(pool)
    pool * REPLAYED_EVERY.in_minutes.to_i * SHARE_OF_POOL_PERCENT / 100
  end

  def perform
    purge_expired
    waiting_job_classes.group_by { it.new.api_pool }.each { |pool, job_classes| replay(pool, job_classes) }
  end

  private

  def purge_expired
    expired = ParkedAPIEntrepriseFetch.where(created_at: ..KEPT_FOR.ago.at_midnight)
    purged_by_job = expired.group(:job).count
    return if purged_by_job.empty?

    expired.delete_all
    Sentry.capture_message("API Entreprise complementary fetches given up after a month of failures",
      level: :error, extra: { purged_by_job: })
  end

  def waiting_job_classes
    ParkedAPIEntrepriseFetch
      .where(job: APIEntreprise::Job::PING_KEY_BY_JOB.keys)
      .distinct
      .pluck(:job)
      .map { "APIEntreprise::#{it}".constantize }
  end

  def replay(pool, job_classes)
    return if APIEntreprise::RateLimiter.throttled?(pool)

    job_classes_by_name = job_classes.reject(&:provider_down?).index_by { it.name.demodulize }
    return if job_classes_by_name.empty?

    batch = not_in_queue
      .where(job: job_classes_by_name.keys)
      .and(due_for_replay)
      .joins(:procedure)
      .merge(Procedure.with_usable_api_entreprise_token)
      .order(:created_at)
      .limit(self.class.batch_size(pool))
      .to_a

    jobs_by_fetch_id = batch.to_h { [it.id, job_for(it, job_classes_by_name.fetch(it.job))] }.compact

    jobs_by_fetch_id.each_slice(ENQUEUED_TOGETHER) do |slice|
      ActiveJob.perform_all_later(slice.map(&:last))
      ParkedAPIEntrepriseFetch.where(id: slice.map(&:first)).update_all(enqueued_at: Time.current)
    end
  end

  def job_for(fetch, job_class)
    job_class.new(*fetch.job_arguments).set(queue: :low, wait: rand(0..SPREAD_OVER))
  rescue ActiveJob::DeserializationError
    nil
  end

  def not_in_queue
    ParkedAPIEntrepriseFetch.where(enqueued_at: nil).or(ParkedAPIEntrepriseFetch.where(enqueued_at: ..LOST_AFTER.ago))
  end

  def due_for_replay
    ParkedAPIEntrepriseFetch.where(daily_failures: nil, updated_at: ..REPLAYED_EVERY.ago)
      .or(ParkedAPIEntrepriseFetch.where.not(daily_failures: nil).where(updated_at: ..RETRIED_DAILY_EVERY.ago))
  end
end
