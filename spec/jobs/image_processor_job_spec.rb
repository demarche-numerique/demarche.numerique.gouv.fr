# frozen_string_literal: true

describe ImageProcessorJob, type: :job do
  let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }
  let(:procedure) { create(:procedure).tap { allow(_1).to receive(:valid?).and_return(true) } }
  let(:blob) do
    procedure.notice.attach(file)
    procedure.notice.blob
  end

  it 'enqueues a BlobProcessorJob' do
    expect {
      ImageProcessorJob.perform_now(blob)
    }.to have_enqueued_job(BlobProcessorJob).with(blob)
  end

  context 'when the blob has been deleted' do
    before { ActiveStorage::Blob.find(blob.id).purge }

    it 'ignores the error' do
      expect { ImageProcessorJob.perform_now(blob) }.not_to raise_error
    end
  end
end
