# frozen_string_literal: true

describe ProcedureArchiveWeightConcern do
  describe '#average_dossier_weight', :caching do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :piece_justificative }]) }

    def dossier_with_pj(byte_size, *traits)
      dossier = create(:dossier, :accepte, :with_populated_champs, *traits, procedure:)
      dossier.champs.flat_map(&:piece_justificative_file_attachments).each { it.blob.update!(byte_size:) }
      dossier
    end

    it 'is nil without a terminated dossier, and remembers it' do
      expect(procedure.average_dossier_weight).to be_nil
      dossier_with_pj(4)
      expect(procedure.average_dossier_weight).to be_nil
    end

    it 'adds the dossier pdf to the average pièces jointes of the sample' do
      [4, 5, 6].each { dossier_with_pj(it) }

      expect(procedure.average_dossier_weight).to eq(5 + ExportedFilesSizeConcern::DOSSIER_PDF_WEIGHT)
    end

    it 'computes the estimate once' do
      dossier_with_pj(4)

      expect { dossier_with_pj(1000) }.not_to change { procedure.average_dossier_weight }
    end

    it 'counts the other attachments the archive ships' do
      dossier = dossier_with_pj(10, :with_justificatif)
      dossier.justificatif_motivation.blob.update!(byte_size: 20)
      commentaire = create(:commentaire, :with_file, dossier:)
      commentaire.piece_jointe.first.blob.update!(byte_size: 30, virus_scan_result: ActiveStorage::VirusScanner::SAFE)

      expect(procedure.average_dossier_weight).to eq(60 + ExportedFilesSizeConcern::DOSSIER_PDF_WEIGHT)
    end

    it 'skips what the archive skips: purged blobs, unscanned blobs, hidden dossiers' do
      dossier = dossier_with_pj(4)
      champ = dossier.champs.find(&:piece_justificative?)
      champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'purged.txt', metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE })
      champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'unscanned.txt')
      blobs = champ.piece_justificative_file_blobs.index_by { it.filename.to_s }
      blobs['purged.txt'].update!(byte_size: 1000, soft_deleted_at: Time.current)
      blobs['unscanned.txt'].update!(byte_size: 1000)
      dossier_with_pj(1000, :hidden_by_administration)

      expect(procedure.average_dossier_weight).to eq(4 + ExportedFilesSizeConcern::DOSSIER_PDF_WEIGHT)
    end

    it 'skips the pièces justificatives of the champs the revision no longer has' do
      dossier = dossier_with_pj(4)
      orphan_champ = dossier.champs.find(&:piece_justificative?).dup
      orphan_champ.update!(stable_id: orphan_champ.stable_id + 1)
      orphan_champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'removed.txt', metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE })
      orphan_champ.piece_justificative_file_blobs.each { it.update!(byte_size: 1000) }

      expect(procedure.average_dossier_weight).to eq(4 + ExportedFilesSizeConcern::DOSSIER_PDF_WEIGHT)
    end

    context 'with a repetition' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :repetition, children: [{ type: :piece_justificative }] }]) }

      it 'skips the pièces justificatives of a removed row' do
        dossier = dossier_with_pj(4)
        dossier.champ_data.find(&:row?).discard!

        expect(procedure.average_dossier_weight).to eq(4 + ExportedFilesSizeConcern::DOSSIER_PDF_WEIGHT)
      end
    end

    it 'skips the pièces jointes the history streams keep' do
      dossier = dossier_with_pj(4)
      history_champ = dossier.champs.find(&:piece_justificative?).dup
      history_champ.update!(stream: "#{Dossier::HISTORY_STREAM}#{Time.current}")
      history_champ.piece_justificative_file.attach(io: StringIO.new('x'), filename: 'replaced.txt', metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE })
      history_champ.piece_justificative_file_blobs.each { it.update!(byte_size: 1000) }

      expect(procedure.average_dossier_weight).to eq(4 + ExportedFilesSizeConcern::DOSSIER_PDF_WEIGHT)
    end
  end
end
