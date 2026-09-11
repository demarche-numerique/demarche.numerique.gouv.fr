# frozen_string_literal: true

RSpec.describe Cron::PurgeUnattachedBlobsJob, type: :job do
  describe 'perform' do
    subject { described_class.perform_now }

    def unattached_blob(name, created_at)
      ActiveStorage::Blob
        .create_and_upload!(io: StringIO.new(name), filename: "#{name}.txt", content_type: "text/plain")
        .tap { it.update_column(:created_at, created_at) }
    end

    # unattached, within the created_at window
    let(:blob) { unattached_blob("data", 3.days.ago) }
    let(:blob_too_old) { unattached_blob("old", 8.days.ago) }

    context 'when the blob has not been soft-deleted' do
      before { blob }

      it 'enqueues a purge' do
        expect { subject }.to have_enqueued_job(DelayedPurgeJob).with(blob)
      end
    end

    context 'when the blob has already been soft-deleted' do
      before { blob.update_column(:soft_deleted_at, 1.hour.ago) }

      it 'does not enqueue a purge' do
        expect { subject }.not_to have_enqueued_job(DelayedPurgeJob)
      end
    end

    context 'when the blob is outside the window' do
      let(:blob_too_recent) { unattached_blob("recent", 1.hour.ago) }

      # ids grow with created_at in production: create the blobs in that order
      before do
        blob_too_old
        blob
        blob_too_recent
      end

      # `with` filters the enqueued jobs before counting: the unfiltered count
      # is what proves the other two blobs were left alone
      it 'leaves it alone' do
        expect { subject }.to have_enqueued_job(DelayedPurgeJob).once
          .and have_enqueued_job(DelayedPurgeJob).with(blob)
      end
    end

    context 'when the window spans several id slices' do
      let(:other_blob) { unattached_blob("more", 2.days.ago) }

      # the old blob anchors the first id right before the window, so that the
      # one-id slices only walk the window instead of every id since the seeds
      before do
        blob_too_old
        blob
        other_blob
        stub_const('Cron::PurgeUnattachedBlobsJob::ID_SLICE', 1)
      end

      it 'covers every slice, last id included' do
        expect { subject }.to have_enqueued_job(DelayedPurgeJob).twice
          .and have_enqueued_job(DelayedPurgeJob).with(blob)
          .and have_enqueued_job(DelayedPurgeJob).with(other_blob)
      end
    end
  end
end
