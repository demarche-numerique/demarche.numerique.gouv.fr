# frozen_string_literal: true

RSpec.describe Attachment::PieceJustificativeService do
  let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_public_champs.first }

  let(:blob_1) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new("file1"), filename: "file1.pdf", content_type: "application/pdf") }
  let(:blob_2) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new("file2"), filename: "file2.pdf", content_type: "application/pdf") }

  describe '.attach_champ_pj' do
    context 'with sequential uploads' do
      it 'preserves all attachments' do
        described_class.attach_champ_pj(champ, blob_1.signed_id)
        described_class.attach_champ_pj(champ, blob_2.signed_id)

        expect(champ.reload.piece_justificative_file.count).to eq(2)
      end
    end

    context 'with concurrent uploads (simulated stale state)' do
      it 'preserves all attachments' do
        champ_a = Dossier.find(dossier.id).root_public_champs.first
        champ_b = Dossier.find(dossier.id).root_public_champs.first

        # Force-load the blobs association on both instances before either attaches.
        # This simulates two concurrent requests that both read blobs = [] at the same time.
        champ_a.piece_justificative_file.blobs.to_a
        champ_b.piece_justificative_file.blobs.to_a

        described_class.attach_champ_pj(champ_a, blob_1.signed_id)
        described_class.attach_champ_pj(champ_b, blob_2.signed_id)

        expect(champ.reload.piece_justificative_file.count).to eq(2)
      end
    end

    context 'with an OCR-compatible PJ (justificatif de domicile)' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative, nature: 'justificatif_domicile' }]) }

      it 'transitions the champ to waiting_for_job in the same transaction' do
        described_class.attach_champ_pj(champ, blob_1.signed_id)

        expect(champ.reload).to be_waiting_for_job
      end
    end

    context 'with a non-OCR PJ' do
      it 'leaves the champ idle' do
        described_class.attach_champ_pj(champ, blob_1.signed_id)

        expect(champ.reload).to be_idle
      end
    end

    context 'when the PJ is conditioned on a champ edited in the user buffer' do
      include Logic

      let(:procedure) do
        create(:procedure, :published, types_de_champ_public: [
          { type: :yes_no, stable_id: 99 },
          { type: :piece_justificative, stable_id: 999, condition: ds_eq(champ_value(99), constant(true)) },
        ])
      end
      let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
      let(:invalid_blob) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "bad.exe", content_type: "application/x-ms-dos-executable") }

      it 'computes visibility on the update stream, so the upload is validated' do
        dossier.champ_data.find { _1.stable_id == 99 }.update_column(:value, 'false')

        dossier.with_update_stream(dossier.user)
        yes_no_champ = dossier.champ_for_update(dossier.find_type_de_champ_by_stable_id(99), row_id: nil, updated_by: dossier.user.email)
        yes_no_champ.update(value: 'true')
        pj_champ = dossier.champ_for_update(dossier.find_type_de_champ_by_stable_id(999), row_id: nil, updated_by: dossier.user.email)

        expect(described_class.attach_champ_pj(pj_champ, invalid_blob.signed_id)).to be_falsey
        expect(pj_champ.errors[:piece_justificative_file]).to be_present
      end
    end
  end
end
