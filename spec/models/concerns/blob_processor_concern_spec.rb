# frozen_string_literal: true

describe BlobProcessorConcern do
  describe '#processed?' do
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("content"), filename: "test.png", content_type: "image/png")
    end

    context 'when blob has metadata processed flag' do
      before { blob.update!(metadata: blob.metadata.merge("processed" => true)) }

      it { expect(blob.processed?).to be true }
    end

    context 'when blob virus scan is done (legacy blob)' do
      before { blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::SAFE) }

      it { expect(blob.processed?).to be true }
    end

    context 'when blob is pending (new upload)' do
      it { expect(blob.processed?).to be false }
    end
  end

  describe '#watermark_pending?' do
    context 'with PieceJustificativeChamp with nature=titre_identite' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, :en_construction, procedure:) }
      let(:champ) { dossier.champs.first }

      it 'requires watermark' do
        champ.piece_justificative_file.attach(
          io: StringIO.new("image content"),
          filename: "identite.png",
          content_type: "image/png"
        )

        blob = champ.piece_justificative_file.attachments.first.blob

        expect(blob.watermark_pending?).to be true
      end
    end

    context 'with PieceJustificativeChamp with nature=titre_identite' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, :en_construction, procedure:) }
      let(:champ) { dossier.champs.first }

      it 'requires watermark' do
        champ.piece_justificative_file.attach(
          io: StringIO.new("image content"),
          filename: "identite.png",
          content_type: "image/png"
        )

        blob = champ.piece_justificative_file.attachments.first.blob

        expect(blob.watermark_pending?).to be true
      end
    end

    context 'with regular PieceJustificativeChamp (no nature)' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, :en_construction, procedure:) }
      let(:champ) { dossier.champs.first }

      it 'does not require watermark' do
        champ.piece_justificative_file.attach(
          io: StringIO.new("document content"),
          filename: "document.pdf",
          content_type: "application/pdf"
        )

        blob = champ.piece_justificative_file.attachments.first.blob

        expect(blob.watermark_pending?).to be false
      end
    end
  end
end
