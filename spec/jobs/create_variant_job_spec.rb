# frozen_string_literal: true

describe CreateVariantJob, type: :job do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.project_champs_public.first }
  let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }

  let(:attachment) do
    champ.piece_justificative_file.attach(file)
    champ.piece_justificative_file.attachments.first
  end

  before do
    allow(attachment).to receive(:representation_required?).and_return(true)
  end

  describe '#perform' do
    context 'when attachment is an image' do
      it 'creates a variant' do
        expect { described_class.perform_now(attachment.id) }.to change { ActiveStorage::VariantRecord.count }.by(1)
      end
    end

    context 'when attachment is a rare image type' do
      let(:file) { fixture_file_upload('spec/fixtures/files/pencil.tiff', 'image/tiff') }

      it 'creates two variants' do
        expect { described_class.perform_now(attachment.id) }.to change { ActiveStorage::VariantRecord.count }.by(2)
      end
    end

    context 'when attachment is a pdf', :external_deps do
      let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

      it 'creates a representation' do
        expect { described_class.perform_now(attachment.id) }.to change { ActiveStorage::VariantRecord.count }.by(1)
      end
    end

    context 'when attachment does not exist' do
      it 'does not raise an error' do
        expect { described_class.perform_now(-1) }.not_to raise_error
      end
    end

    context 'when file_type filter is specified' do
      context 'when file_type is image and attachment is image' do
        it 'creates a variant' do
          expect { described_class.perform_now(attachment.id, file_type: 'image') }.to change { ActiveStorage::VariantRecord.count }.by(1)
        end
      end

      context 'when file_type is pdf and attachment is image' do
        it 'does not create a variant' do
          expect { described_class.perform_now(attachment.id, file_type: 'pdf') }.not_to change { ActiveStorage::VariantRecord.count }
        end
      end

      context 'when file_type is image and attachment is pdf', :external_deps do
        let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

        it 'does not create a representation' do
          expect { described_class.perform_now(attachment.id, file_type: 'image') }.not_to change { ActiveStorage::VariantRecord.count }
        end
      end
    end
  end

  describe 'queue' do
    it 'uses the backfill queue' do
      expect(described_class.new.queue_name).to eq('backfill')
    end
  end
end
