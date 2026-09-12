# frozen_string_literal: true

class Cron::CronJob < ApplicationJob
  # A cron job is scheduled again anyway: the next run is the retry. With the
  # default budget of 25 retries, a nightly job that fails on a statement
  # timeout is retried for about three weeks, so a dozen instances of the same
  # job overlap and every failure yields a dozen Sentry events. A job whose run
  # cannot be caught up by the next one opts back in with `use_sidekiq_retry`.
  use_sidekiq_retry(retry: 2)

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
  end
end
