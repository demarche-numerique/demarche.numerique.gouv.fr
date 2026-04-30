# frozen_string_literal: true

RSpec.describe Cron::FixMissingAntivirusAnalysisJob, type: :job do
  let(:blob_pending) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("pending"), filename: "pending.txt", content_type: "text/plain").tap do |blob|
      blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::PENDING, created_at: 3.days.ago)
    end
  end

  let(:blob_too_recent) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("recent"), filename: "recent.txt", content_type: "text/plain").tap do |blob|
      blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::PENDING, created_at: 1.hour.ago)
    end
  end

  let(:blob_too_old) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("old"), filename: "old.txt", content_type: "text/plain").tap do |blob|
      blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::PENDING, created_at: 2.weeks.ago)
    end
  end

  let(:blob_already_safe) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("safe"), filename: "safe.txt", content_type: "text/plain").tap do |blob|
      blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::SAFE, created_at: 3.days.ago)
    end
  end

  let(:blob_already_processed) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("processed"), filename: "processed.txt", content_type: "text/plain").tap do |blob|
      blob.update_columns(
        virus_scan_result: ActiveStorage::VirusScanner::PENDING,
        created_at: 3.days.ago,
        metadata: blob.metadata.merge("processed" => true)
      )
    end
  end

  before do
    blob_pending
    blob_too_recent
    blob_too_old
    blob_already_safe
    blob_already_processed
  end

  subject(:perform_job) { described_class.perform_now }

  describe '#perform' do
    it 'enqueues BlobProcessorJob only for pending blobs within the time window' do
      expect { perform_job }
        .to have_enqueued_job(BlobProcessorJob).with(blob_pending)
    end

    it 'does not enqueue for blobs created less than 1 day ago' do
      expect { perform_job }
        .not_to have_enqueued_job(BlobProcessorJob).with(blob_too_recent)
    end

    it 'does not enqueue for blobs older than 1 week' do
      expect { perform_job }
        .not_to have_enqueued_job(BlobProcessorJob).with(blob_too_old)
    end

    it 'does not enqueue for already safe blobs' do
      expect { perform_job }
        .not_to have_enqueued_job(BlobProcessorJob).with(blob_already_safe)
    end

    it 'does not enqueue for already processed blobs' do
      expect { perform_job }
        .not_to have_enqueued_job(BlobProcessorJob).with(blob_already_processed)
    end
  end
end
