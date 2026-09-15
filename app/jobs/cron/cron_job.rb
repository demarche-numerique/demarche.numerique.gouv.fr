# frozen_string_literal: true

class Cron::CronJob < ApplicationJob
  # A cron job is scheduled again anyway: the next run is the retry. With the
  # default budget of 25 retries, a nightly job that fails on a statement
  # timeout is retried for about three weeks, so a dozen instances of the same
  # job overlap and every failure yields a dozen Sentry events.
  #
  # A job whose run cannot be caught up by the next one raises its own budget with
  # `use_sidekiq_retry(max_retry:)` -- sized to its window, not to MAX_ATTEMPTS_JOBS.
  # `perform` recomputes the current date at every attempt, so once the retries reach
  # the next run (retry 14 lands a day later) they no longer redo the lost work: they
  # run the next run's scope, in addition to the next run. Past its own window, a
  # retry stops being a catch-up and becomes a duplicate.
  use_sidekiq_retry(max_retry: 2)

  queue_as :default
  class_attribute :schedule_expression

  class << self
    def schedulable?
      ENV['CRON_JOBS_DISABLED'].blank?
    end

    def schedule
      remove if cron_expression_changed?

      if !scheduled?
        Sidekiq::Cron::Job.create(name: name, cron: cron_expression, class: name)
      end
    end

    def remove
      enqueued_cron_job.destroy if scheduled?
    end

    def display_schedule
      pp "#{name}: #{schedule_expression} cron(#{cron_expression})"
    end

    def scheduled?
      enqueued_cron_job.present?
    end

    def cron_expression_changed?
      scheduled? && enqueued_cron_job.cron != cron_expression
    end

    def enqueued_cron_job
      Sidekiq::Cron::Job.find(name)
    end

    def cron_expression
      Fugit.do_parse(schedule_expression, multi: :fail).to_cron_s
    end

    # Registers every schedulable job in Redis and drops the schedules left
    # behind by a deleted or renamed class. Redis is the source of truth for
    # sidekiq-cron, so it drifts from the code until this runs.
    def schedule_all!
      jobs = schedulable_jobs
      jobs.each(&:schedule)
      prune_orphaned_cron_jobs(jobs)
    end

    def schedulable_jobs
      Rails.root.glob('app/jobs/**/*_job.rb').each { require it }
      descendants.filter(&:schedulable?)
    end

    # sidekiq-cron's own `destroy_removed_jobs` only considers jobs with
    # source == "schedule", but ours are created via `Sidekiq::Cron::Job.create`
    # (source == "dynamic"), so we prune by comparing against the known classes.
    def prune_orphaned_cron_jobs(jobs)
      known_classes = jobs.map(&:name).to_set
      Sidekiq::Cron::Job.all.each do |cron_job| # rubocop:disable Rails/FindEach -- not an ActiveRecord relation
        cron_job.destroy unless known_classes.include?(cron_job.klass)
      end
    end
  end
end
