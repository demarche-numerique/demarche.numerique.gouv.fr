# frozen_string_literal: true

namespace :jobs do
  desc 'Schedule all schedulable cron jobs'
  task schedule: :environment do
    Cron::CronJob.schedule_all!
  end

  desc 'Display schedule for all schedulable cron jobs'
  task display_schedule: :environment do
    Cron::CronJob.schedulable_jobs.each(&:display_schedule)
  end
end
