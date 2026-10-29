# frozen_string_literal: true

describe ExportJob do
  let(:procedure) { create(:procedure, instructeurs: [user_profile]) }
  let(:user_profile) { create(:instructeur) }
  let(:time_span_type) { :everything }
  let(:status) { :tous }
  let(:key) { '123' }
  let(:export) do
    create(:export, format:,
                    time_span_type:,
                    key:,
                    user_profile:,
                    groupe_instructeurs: procedure.groupe_instructeurs)
  end

  subject do
    ExportJob.perform_now(export)
  end
  before do
    allow_any_instance_of(ArchiveUploader).to receive(:syscall_to_custom_uploader).and_return(true)
  end

  context 'zip' do
    let(:format) { :zip }

    it 'does not try to identify file' do
      expect { subject }.not_to raise_error
    end

    context 'when its files exceed the limit' do
      before do
        create(:dossier, :en_construction, procedure:)
        stub_const('Export::MAX_FILES_SIZE', 100.kilobytes)
      end

      it 'flags the export instead of building it' do
        subject

        expect(export.reload).to have_attributes(job_status: 'too_large', estimated_files_size: 110.kilobytes)
        expect(export.file).not_to be_attached
      end
    end
  end

  context 'csv whose dossiers carry files over the limit' do
    let(:format) { :csv }

    before do
      create(:dossier, :en_construction, procedure:)
      stub_const('Export::MAX_FILES_SIZE', 100.kilobytes)
    end

    it 'builds the export' do
      subject

      expect(export.reload.job_status).to eq('generated')
    end
  end
end
