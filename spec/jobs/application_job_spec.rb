# frozen_string_literal: true

include ActiveJob::TestHelper

RSpec.describe ApplicationJob, type: :job do
  describe 'perform' do
    before do
      allow(Rails.logger).to receive(:info)
    end

    it 'logs start time and end time' do
      perform_enqueued_jobs { ChildJob.perform_later }
      expect(Rails.logger).to have_received(:info).with(/started at/).once
      expect(Rails.logger).to have_received(:info).with(/ended at/).once
    end

    it 'exposes the job_id in Current during perform' do
      job = ChildJob.perform_later
      perform_enqueued_jobs
      expect(ChildJob.current_job_id).to eq(job.job_id)
    end
  end

  describe 'sentry tags' do
    before { allow(Sentry).to receive(:set_tags) }

    it 'tags a dossier passed after the first argument' do
      dossier = dossiers.en_construction
      perform_enqueued_jobs { TaggedJob.perform_later('noise', dossier) }

      expect(Sentry).to have_received(:set_tags).with(dossier: dossier.id, procedure: dossier.procedure.id)
    end

    it 'tags the dossier of a record belonging to one' do
      pending_avis = avis.pending
      perform_enqueued_jobs { TaggedJob.perform_later(pending_avis) }

      expect(Sentry).to have_received(:set_tags).with(dossier: pending_avis.dossier_id)
    end
  end

  class TaggedJob < ApplicationJob
    def perform(*) = nil
  end

  class ChildJob < ApplicationJob
    class << self
      attr_accessor :current_job_id
    end

    def perform
      self.class.current_job_id = Current.job_id
    end
  end
end
