# frozen_string_literal: true

describe ProcedureDossierVidePdfConcern do
  let(:procedure) { create(:procedure, :published, :with_service, libelle: 'Ma démarche') }
  let(:revision) { procedure.published_revision }

  describe '#dossier_vide_pdf_cache_key_for' do
    it 'changes when the revision changes' do
      before_key = procedure.dossier_vide_pdf_cache_key_for(revision)

      expect(procedure.dossier_vide_pdf_cache_key_for(procedure.draft_revision)).not_to eq(before_key)
    end

    it 'changes when the procedure is updated' do
      before_key = procedure.dossier_vide_pdf_cache_key_for(revision)
      procedure.update!(description: 'Une nouvelle présentation')

      expect(procedure.dossier_vide_pdf_cache_key_for(revision)).not_to eq(before_key)
    end

    it 'changes when the service is updated' do
      before_key = procedure.dossier_vide_pdf_cache_key_for(revision)
      procedure.service.update!(adresse: '2 rue de la Paix, 75002 Paris')

      expect(procedure.reload.dossier_vide_pdf_cache_key_for(revision)).not_to eq(before_key)
    end

    it 'changes when the cache version is bumped, which is how rendering changes are caught' do
      before_key = procedure.dossier_vide_pdf_cache_key_for(revision)
      stub_const('ProcedureDossierVidePdfConcern::CACHE_VERSION', ProcedureDossierVidePdfConcern::CACHE_VERSION + 1)

      expect(procedure.dossier_vide_pdf_cache_key_for(revision)).not_to eq(before_key)
    end

    it 'changes when a Typst template changes' do
      before_key = procedure.dossier_vide_pdf_cache_key_for(revision)
      stub_const('ProcedureDossierVidePdfConcern::TEMPLATES_DIGEST', 'edited-theme')

      expect(procedure.dossier_vide_pdf_cache_key_for(revision)).not_to eq(before_key)
    end

    it 'is stable when nothing changed' do
      expect(procedure.dossier_vide_pdf_cache_key_for(revision))
        .to eq(procedure.dossier_vide_pdf_cache_key_for(revision))
    end

    it 'works for a procedure without a service' do
      procedure.update!(service: nil, organisation: 'Une organisation')

      expect(procedure.dossier_vide_pdf_cache_key_for(revision)).to be_present
    end
  end

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
