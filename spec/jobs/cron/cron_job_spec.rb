# frozen_string_literal: true

RSpec.describe Cron::CronJob, type: :job do
  describe '#schedulable?' do
    it 'is schedulable by default' do
      expect(Cron::CronJob.schedulable?).to be_truthy
    end
  end

  describe 'retries' do
    it 'caps Sidekiq retries: the next scheduled run is the retry' do
      expect(Cron::CronJob.get_sidekiq_options['retry']).to eq(2)
      expect(Cron::PurgeSoftDeletedBlobsJob.get_sidekiq_options['retry']).to eq(2)
    end

    it 'lets a job whose run cannot be caught up keep the full budget' do
      expect(Cron::PurgeOldBrevoMailsJob.get_sidekiq_options['retry']).to eq(ActiveJob::RetryOnStandardError::MAX_ATTEMPTS_JOBS)
      expect(Cron::Datagouv::AccountByMonthJob.get_sidekiq_options['retry']).to eq(ActiveJob::RetryOnStandardError::MAX_ATTEMPTS_JOBS)
      expect(Cron::Datagouv::ExportAndPublishDemarchesPubliquesJob.get_sidekiq_options['retry']).to eq(ActiveJob::RetryOnStandardError::MAX_ATTEMPTS_JOBS)
    end
  end
end
