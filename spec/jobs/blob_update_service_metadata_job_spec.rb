# frozen_string_literal: true

describe BlobUpdateServiceMetadataJob, type: :job do
  let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }
  let(:procedure) { create(:procedure).tap { allow(_1).to receive(:valid?).and_return(true) } }
  let(:blob) do
    procedure.notice.attach(file)
    procedure.notice.blob
  end

  describe 'the after_update_commit callback on ActiveStorage::Blob' do
    it 'enqueues the job rather than calling the storage inside the request' do
      expect(blob.service).not_to receive(:update_metadata)

      expect { blob.update!(content_type: 'application/pdf') }
        .to have_enqueued_job(BlobUpdateServiceMetadataJob).with(blob)
    end

    it 'does not fail the caller when the storage refuses the metadata update' do
      blob # attach before stubbing
      allow(blob.service).to receive(:update_metadata).and_raise(Excon::Error::Conflict.new('409'))

      expect { blob.update!(content_type: 'application/pdf') }.not_to raise_error
    end
  end

  describe '#perform' do
    it 'pushes the metadata to the storage service' do
      expect(blob.service).to receive(:update_metadata)
        .with(blob.key, hash_including(content_type: blob.content_type))

      BlobUpdateServiceMetadataJob.perform_now(blob)
    end
  end
end
