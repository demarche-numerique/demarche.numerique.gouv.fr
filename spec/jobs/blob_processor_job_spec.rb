# frozen_string_literal: true

describe BlobProcessorJob, :external_deps, type: :job do
  include Dry::Monads[:result]

  let(:watermark_service) { instance_double("WatermarkService") }

  let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }

  let(:procedure) do
    create(:procedure).tap { allow(_1).to receive(:valid?).and_return(true) }
  end

  let(:blob) do
    procedure.notice.attach(file)
    procedure.notice.blob
  end

  before do
    require "vips"

    allow(WatermarkService).to receive(:new).and_return(watermark_service)
    allow(watermark_service).to receive(:apply) { |image, **| image }
  end

  describe 'virus scanning' do
    context 'when virus scan passes' do
      before do
        allow(ClamavService).to receive(:safe_file?).and_return(true)
        described_class.perform_now(blob)
      end

      it 'marks blob as safe' do
        expect(blob.virus_scanner.safe?).to be_truthy
      end

      it 'sets processed metadata' do
        expect(blob.metadata["processed"]).to be true
      end
    end

    context 'when virus scan fails' do
      before do
        allow(ClamavService).to receive(:safe_file?).and_return(false)
        described_class.perform_now(blob)
      end

      it 'marks blob as infected' do
        expect(blob.virus_scanner.infected?).to be_truthy
      end

      it 'does not process images' do
        expect(watermark_service).not_to have_received(:apply)
      end

      it 'sets processed metadata' do
        expect(blob.metadata["processed"]).to be true
      end
    end

    context 'when virus scan is already done (idempotent re-run)' do
      before do
        blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::SAFE, virus_scanned_at: Time.current)
        allow(ClamavService).to receive(:safe_file?)
        described_class.perform_now(blob)
      end

      it 'does not re-scan' do
        expect(ClamavService).not_to have_received(:safe_file?)
      end
    end
  end

  describe 'autorotate' do
    before do
      allow(ClamavService).to receive(:safe_file?).and_return(true)
    end

    context 'when image is not a jpg' do
      it 'does not re-upload the blob' do
        expect { described_class.perform_now(blob) }.not_to change { blob.reload.checksum }
      end
    end

    context 'when image is a jpg with rotation EXIF' do
      let(:file) { fixture_file_upload('spec/fixtures/files/image-rotated.jpg', 'image/jpeg') }

      it 'rotates the image and re-uploads' do
        blob.open do |tempfile|
          image = Vips::Image.new_from_file(tempfile.path)
          orientation = image.get("orientation")
          expect(orientation).to eq(8)
        end

        expect { described_class.perform_now(blob) }.to change { blob.reload.checksum }

        blob.open do |tempfile|
          image = Vips::Image.new_from_file(tempfile.path)
          orientation = image.get("orientation")
          expect(orientation).to eq(1)
        end
      end
    end

    context 'when image is a jpg without rotation' do
      let(:file) { fixture_file_upload('spec/fixtures/files/image-no-rotation.jpg', 'image/jpeg') }

      it 'does not re-upload the blob' do
        expect { described_class.perform_now(blob) }.not_to change { blob.reload.checksum }
      end
    end
  end

  describe 'uninterlace' do
    before do
      allow(ClamavService).to receive(:safe_file?).and_return(true)
    end

    context 'when PNG attached as attestation logo is interlaced' do
      let(:file) { fixture_file_upload('spec/fixtures/files/interlaced-black.png', 'image/png') }
      let(:attestation_template) { create(:attestation_template, procedure:) }
      let(:blob) do
        attestation_template.logo.attach(file)
        attestation_template.logo.blob
      end

      it 'uninterlaces and re-uploads' do
        blob.open do |tempfile|
          image = Vips::Image.new_from_file(tempfile.path)
          interlaced = image.get_fields.include?("interlaced")
          expect(interlaced).to eq(true)
        end

        expect { described_class.perform_now(blob) }.to change { blob.reload.checksum }

        blob.open do |tempfile|
          image = Vips::Image.new_from_file(tempfile.path)
          interlaced = image.get_fields.include?("interlaced")
          expect(interlaced).to eq(false)
        end
      end
    end

    context 'when PNG attestation logo is not interlaced' do
      let(:file) { fixture_file_upload('spec/fixtures/files/uninterlaced-black.png', 'image/png') }
      let(:attestation_template) { create(:attestation_template, procedure:) }
      let(:blob) do
        attestation_template.logo.attach(file)
        attestation_template.logo.blob
      end

      it 'does not re-upload the blob' do
        expect { described_class.perform_now(blob) }.not_to change { blob.reload.checksum }
      end
    end

    context 'when PNG is not an attestation image' do
      it 'does not re-upload the blob' do
        expect { described_class.perform_now(blob) }.not_to change { blob.reload.checksum }
      end
    end
  end

  describe 'create representation' do
    before do
      allow(ClamavService).to receive(:safe_file?).and_return(true)
    end

    context 'when representation is not required' do
      it 'does not create blob representation' do
        expect { described_class.perform_now(blob) }.not_to change { ActiveStorage::VariantRecord.count }
      end
    end

    context 'when representation is required' do
      before { allow(blob).to receive(:representation_required?).and_return(true) }

      it 'creates blob representation' do
        expect { described_class.perform_now(blob) }.to change { ActiveStorage::VariantRecord.count }.by(1)
      end
    end

    context 'when type image is rare (TIFF)' do
      let(:file) { fixture_file_upload('spec/fixtures/files/pencil.tiff', 'image/tiff') }
      before { allow(blob).to receive(:representation_required?).and_return(true) }

      it 'creates two variants' do
        expect { described_class.perform_now(blob) }.to change { ActiveStorage::VariantRecord.count }.by(2)
      end
    end

    context 'when file is a PDF' do
      let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }
      before { allow(blob).to receive(:representation_required?).and_return(true) }

      it 'creates blob representation' do
        expect { described_class.perform_now(blob) }.to change { ActiveStorage::VariantRecord.count }.by(1)
      end
    end
  end

  describe 'watermark' do
    before do
      allow(ClamavService).to receive(:safe_file?).and_return(true)
    end

    context 'when watermark is already done' do
      before { allow(blob).to receive(:watermark_done?).and_return(true) }

      it 'does not apply the watermark' do
        expect(watermark_service).not_to receive(:apply)
        described_class.perform_now(blob)
      end
    end

    context 'when the blob is ready to be watermarked' do
      before do
        allow(blob).to receive(:watermark_pending?).and_return(true)
      end

      it 'applies watermark and sets watermarked_at' do
        expect {
          described_class.perform_now(blob)
        }.to change { blob.reload.checksum }

        expect(watermark_service).to have_received(:apply).with(an_instance_of(Vips::Image), format: blob.content_type)
        expect(blob.watermarked_at).to be_present
      end
    end
  end

  describe 'add ocr data' do
    let(:procedure) do
      create(:procedure,
             types_de_champ_public: [{ type: :piece_justificative, nature: }])
    end
    let(:nature) { "rib" }
    let(:dossier) { create(:dossier, procedure:) }
    let(:analysis) { { "some" => "data" } }
    let(:champ_pj) { dossier.project_champs_public.first }

    let(:blob) do
      pj = champ_pj.piece_justificative_file
      pj = pj.attach(file)
      champ_pj.fetch_later! # to set the state to waiting_for_job
      pj.blobs.first
    end

    before do
      allow(ClamavService).to receive(:safe_file?).and_return(true)
      allow(OCRService).to receive(:analyze).and_return(Success(value_json: analysis))

      described_class.perform_now(blob)
    end

    context "when the blob contains a RIB" do
      it "calls OcrService.analyze with the blob" do
        expect(champ_pj.reload.value_json).to eq(analysis)
      end
    end

    context "when the blob does not contain a RIB" do
      let(:nature) { nil }

      it "does not call OcrService.analyze nor set ocr data" do
        expect(OCRService).not_to have_received(:analyze)
        expect(champ_pj.reload.value_json).to be_nil
      end
    end

    context "when the blob is not attached to a champ PJ" do
      let(:blob) do
        procedure.notice.attach(file)
        procedure.notice.blob
      end

      it "does not call OcrService.analyze nor set ocr data" do
        expect(OCRService).not_to have_received(:analyze)
        expect(champ_pj.reload.value_json).to be_nil
      end
    end

    context "when the champ is already fetched" do
      let(:blob) do
        pj = champ_pj.piece_justificative_file
        pj.attach(file)

        # simulate another blob attached and analyzed (by a invitee, after rebase, …)
        champ_pj.update_column(:external_state, :fetched)
        pj.blobs.first
      end

      it "does not raise and does not call OcrService.analyze" do
        expect(OCRService).not_to have_received(:analyze)
      end
    end
  end

  describe 'non-processable file types' do
    let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }
    let(:blob) do
      # Create a text blob directly (not through an image attachment)
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("spreadsheet data"), filename: "data.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet").tap do |b|
        procedure.notice.attach(b)
      end
    end

    before do
      allow(ClamavService).to receive(:safe_file?).and_return(true)
      described_class.perform_now(blob)
    end

    it 'virus scans the file' do
      expect(ClamavService).to have_received(:safe_file?)
      expect(blob.virus_scanner.safe?).to be_truthy
    end

    it 'does not apply image mutations' do
      expect(watermark_service).not_to have_received(:apply)
    end

    it 'marks as processed' do
      expect(blob.metadata["processed"]).to be true
    end
  end

  describe 'single download optimization' do
    before do
      allow(ClamavService).to receive(:safe_file?).and_return(true)
    end

    it 'calls blob.open only once for mutations' do
      open_count = 0
      allow(blob).to receive(:open).and_wrap_original do |method, *args, &block|
        open_count += 1
        method.call(*args, &block)
      end

      described_class.perform_now(blob)

      # 1 open for scan+mutations (if any), representations use their own mechanism
      expect(open_count).to be <= 1
    end
  end

  describe 'error handling' do
    context 'when blob has been deleted' do
      before { ActiveStorage::Blob.find(blob.id).purge }

      it 'ignores the error' do
        expect { described_class.perform_now(blob) }.not_to raise_error
      end
    end

    context 'when integrity error (corrupted file)' do
      before do
        blob.update_column('checksum', 'integrity error')
        assert_performed_jobs(5) { described_class.perform_later(blob) }
      end

      it 'marks blob as integrity error after retries' do
        expect(blob.reload.virus_scanner.corrupt?).to be_truthy
      end
    end

    context 'when Vips raises an error' do
      before do
        allow(ClamavService).to receive(:safe_file?).and_return(true)
        allow(blob).to receive(:representation_required?).and_return(true)
        allow_any_instance_of(described_class).to receive(:create_representations)
          .and_raise(Vips::Error.new("unable to load source"))
      end

      it 're-enqueues the job for retry' do
        expect {
          described_class.perform_now(blob)
        }.to have_enqueued_job(described_class).with(blob)
      end
    end

    context 'when watermark service raises an error' do
      before do
        allow(ClamavService).to receive(:safe_file?).and_return(true)
        allow(blob).to receive(:watermark_pending?).and_return(true)
        allow(watermark_service).to receive(:apply)
          .and_raise(WatermarkService::Error.new('addalpha not found'))
      end

      it 're-enqueues the job for retry' do
        expect {
          described_class.perform_now(blob)
        }.to have_enqueued_job(described_class).with(blob)
      end
    end
  end
end
