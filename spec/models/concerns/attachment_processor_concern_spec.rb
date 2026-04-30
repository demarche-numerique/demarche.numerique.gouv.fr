# frozen_string_literal: true

describe AttachmentProcessorConcern do
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("content"), filename: filename, content_type:)
  end
  let(:filename) { "test.png" }
  let(:content_type) { "image/png" }

  describe '#process_later' do
    context 'with a processable image blob' do
      let(:procedure) { create(:procedure) }

      before do
        allow(procedure).to receive(:valid?).and_return(true)
        procedure.notice.attach(blob)
      end

      it 'enqueues BlobProcessorJob' do
        expect(BlobProcessorJob).to have_been_enqueued.with(blob)
      end
    end

    context 'with a non-image blob (text file)' do
      let(:filename) { "test.txt" }
      let(:content_type) { "text/plain" }

      let(:procedure) { create(:procedure) }

      before do
        allow(procedure).to receive(:valid?).and_return(true)
        procedure.notice.attach(blob)
      end

      it 'enqueues BlobProcessorJob (virus scan applies to all types)' do
        expect(BlobProcessorJob).to have_been_enqueued.with(blob)
      end
    end

    context 'with a blob already marked as safe (clone case)' do
      let(:procedure) { create(:procedure) }

      before do
        blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::SAFE)
        allow(procedure).to receive(:valid?).and_return(true)
        procedure.notice.attach(blob)
      end

      it 'does not enqueue BlobProcessorJob' do
        expect(BlobProcessorJob).not_to have_been_enqueued
      end
    end

    context 'with a blob already processed via metadata' do
      let(:procedure) { create(:procedure) }

      before do
        blob.update!(metadata: blob.metadata.merge("processed" => true))
        allow(procedure).to receive(:valid?).and_return(true)
        procedure.notice.attach(blob)
      end

      it 'does not enqueue BlobProcessorJob' do
        expect(BlobProcessorJob).not_to have_been_enqueued
      end
    end

    context 'with a variant record attachment', :external_deps do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: Rails.root.join('spec/fixtures/files/logo_test_procedure.png').open,
          filename: "test.png",
          content_type: "image/png"
        )
      end
      let(:procedure) { create(:procedure) }

      before do
        allow(procedure).to receive(:valid?).and_return(true)
        procedure.notice.attach(blob)
        # Mark original blob as processed (simulates completed BlobProcessorJob)
        blob.update_columns(
          virus_scan_result: ActiveStorage::VirusScanner::SAFE,
          virus_scanned_at: Time.current,
          metadata: blob.metadata.merge("processed" => true)
        )
      end

      it 'does not enqueue BlobProcessorJob and marks variant blob as safe+processed' do
        expect {
          procedure.notice.variant(resize_to_limit: [400, 400]).processed
        }.not_to have_enqueued_job(BlobProcessorJob)

        variant_blob = procedure.notice.variant(resize_to_limit: [400, 400]).processed.blob
        expect(variant_blob.virus_scan_result).to eq(ActiveStorage::VirusScanner::SAFE)
        expect(variant_blob.metadata["processed"]).to be true
      end
    end

    context 'with an empty blob' do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new(""), filename: "empty.png", content_type: "image/png")
      end
      let(:procedure) { create(:procedure) }

      before do
        allow(procedure).to receive(:valid?).and_return(true)
        procedure.notice.attach(blob)
      end

      it 'does not enqueue BlobProcessorJob' do
        expect(BlobProcessorJob).not_to have_been_enqueued
      end
    end
  end
end
