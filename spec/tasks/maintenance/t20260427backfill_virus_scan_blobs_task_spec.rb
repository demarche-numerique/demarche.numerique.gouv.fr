# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260427backfillVirusScanBlobsTask do
    describe '#collection' do
      it 'returns a batch enumerator over all blobs' do
        collection = described_class.new.collection
        expect(collection).to be_a(ActiveRecord::Batches::BatchEnumerator)
        expect(collection.relation.model).to eq(ActiveStorage::Blob)
      end
    end

    describe '#process' do
      let!(:pending_blob) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new("pending"), filename: "p.txt", content_type: "text/plain").tap do |b|
          b.update_columns(virus_scan_result: ActiveStorage::VirusScanner::PENDING)
        end
      end

      let!(:safe_blob) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new("safe"), filename: "s.txt", content_type: "text/plain").tap do |b|
          b.update_columns(virus_scan_result: ActiveStorage::VirusScanner::SAFE)
        end
      end

      let!(:already_processed_blob) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new("done"), filename: "d.txt", content_type: "text/plain").tap do |b|
          b.update_columns(
            virus_scan_result: ActiveStorage::VirusScanner::PENDING,
            metadata: b.metadata.merge("processed" => true)
          )
        end
      end

      let(:batch) { ActiveStorage::Blob.where(id: [pending_blob.id, safe_blob.id, already_processed_blob.id]) }

      it 'enqueues a BlobProcessorJob for pending blobs in the batch' do
        expect { described_class.new.process(batch) }
          .to have_enqueued_job(BlobProcessorJob).with(pending_blob).exactly(:once)
      end

      it 'skips safe blobs' do
        expect { described_class.new.process(batch) }
          .not_to have_enqueued_job(BlobProcessorJob).with(safe_blob)
      end

      it 'skips already processed blobs' do
        expect { described_class.new.process(batch) }
          .not_to have_enqueued_job(BlobProcessorJob).with(already_processed_blob)
      end
    end
  end
end
