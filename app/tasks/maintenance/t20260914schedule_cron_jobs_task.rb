# frozen_string_literal: true

module Maintenance
  class T20260914scheduleCronJobsTask < MaintenanceTasks::Task
    # Runs what `rake jobs:schedule` does, from the maintenance UI: registers
    # every schedulable cron job in Redis and prunes the orphaned schedules.
    #
    # Redis is the source of truth for sidekiq-cron, and nothing re-syncs it on
    # deploy, so it drifts whenever a schedule changes or a job class is
    # renamed. An upgrade that moves the keys sidekiq-cron writes to has the
    # same effect: the jobs are still in Redis, under names the new version
    # does not read.

    include RunnableOnDeployConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    no_collection

    def process
      Cron::CronJob.schedule_all!
    end
  end
end
