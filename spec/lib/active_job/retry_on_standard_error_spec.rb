# frozen_string_literal: true

include ActiveJob::TestHelper

RSpec.describe ActiveJob::RetryOnStandardError do
  # rubocop:disable Rails/ApplicationJob
  class JobWithRetry < ActiveJob::Base
    include ActiveJob::RetryOnStandardError

    def perform(attempts = [])
      attempts << executions
      raise StandardError, "attempt #{executions}" if executions < 3
    end
  end
  # rubocop:enable Rails/ApplicationJob

  it_behaves_like 'a job retrying standard errors', JobWithRetry

  describe 'Sentry reporting on retry' do
    it 'calls Sentry.capture_exception every time the job fails and is re-enqueued to retry' do
      allow(Sentry).to receive(:capture_exception)

      perform_enqueued_jobs do
        JobWithRetry.perform_later([])
      end

      # Job fails at execution 1 and 2, then succeeds at 3 → 2 retries → 2 Sentry reports
      expect(Sentry).to have_received(:capture_exception).with(instance_of(StandardError), anything).twice
    end
  end
end
