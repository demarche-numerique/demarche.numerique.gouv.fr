# frozen_string_literal: true

describe VirusScannerJob, type: :job do
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("toto"), filename: "toto.txt", content_type: "text/plain")
  end

  it 'enqueues a BlobProcessorJob' do
    expect {
      VirusScannerJob.perform_now(blob)
    }.to have_enqueued_job(BlobProcessorJob).with(blob)
  end

  context 'when the blob has been deleted' do
    before { ActiveStorage::Blob.find(blob.id).purge }

    it 'ignores the error' do
      expect { VirusScannerJob.perform_now(blob) }.not_to raise_error
    end
  end
end
