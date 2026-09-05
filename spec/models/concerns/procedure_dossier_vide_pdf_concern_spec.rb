# frozen_string_literal: true

describe ProcedureDossierVidePdfConcern do
  let(:procedure) { create(:procedure, :published, :with_service, libelle: 'Ma démarche') }
  let(:revision) { procedure.published_revision }

  describe '#dossier_vide_pdf_fresh?' do
    it 'is false when nothing has been cached yet' do
      expect(procedure.dossier_vide_pdf_fresh?('key')).to be false
    end

    it 'is true when the cached PDF matches the key' do
      procedure.store_dossier_vide_pdf('%PDF-fake', cache_key: 'key')

      expect(procedure.dossier_vide_pdf_fresh?('key')).to be true
    end

    it 'is false when the key differs' do
      procedure.store_dossier_vide_pdf('%PDF-fake', cache_key: 'key')

      expect(procedure.dossier_vide_pdf_fresh?('other-key')).to be false
    end

    it 'is false once the cached PDF has expired' do
      procedure.store_dossier_vide_pdf('%PDF-fake', cache_key: 'key')
      procedure.dossier_vide_pdf.blob.update_column(:created_at, 8.days.ago)

      expect(procedure.reload.dossier_vide_pdf_fresh?('key')).to be false
    end
  end

  describe '#store_dossier_vide_pdf' do
    it 'attaches the PDF, named after the procedure, with the key in its metadata' do
      procedure.store_dossier_vide_pdf('%PDF-fake', cache_key: 'key')

      expect(procedure.dossier_vide_pdf.download).to eq('%PDF-fake')
      expect(procedure.dossier_vide_pdf.filename.to_s).to eq('Ma démarche.pdf')
      expect(procedure.dossier_vide_pdf.blob.metadata[ProcedureDossierVidePdfConcern::CACHE_KEY_METADATA]).to eq('key')
    end

    it 'replaces a previously cached PDF' do
      procedure.store_dossier_vide_pdf('%PDF-old', cache_key: 'key')
      procedure.store_dossier_vide_pdf('%PDF-new', cache_key: 'other-key')

      expect(procedure.reload.dossier_vide_pdf.download).to eq('%PDF-new')
      expect(procedure.dossier_vide_pdf_fresh?('other-key')).to be true
    end

    it 'does not enqueue a virus scan: we generated this PDF ourselves' do
      procedure.store_dossier_vide_pdf('%PDF-fake', cache_key: 'key')

      expect(BlobProcessorJob).not_to have_been_enqueued
    end

    it 'does not bump updated_at, which would invalidate the key it just wrote' do
      procedure # create it before measuring

      expect { procedure.store_dossier_vide_pdf('%PDF-fake', cache_key: 'key') }
        .not_to change { procedure.reload.updated_at }
    end
  end
end
