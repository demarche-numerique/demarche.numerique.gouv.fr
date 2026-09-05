# frozen_string_literal: true

describe DossierVidePdfService do
  let(:procedure) { create(:procedure, :published, :with_service, :with_path, libelle: 'Ma démarche') }
  let(:revision) { procedure.published_revision }

  subject(:pdf) { described_class.render(revision) }

  describe '.render' do
    context 'without any flag' do
      it 'renders the Prawn template' do
        allow(TypstService).to receive(:generate_pdf)
        allow(WeasyprintService).to receive(:generate_pdf)

        expect(pdf).to start_with('%PDF-1.')
        expect(TypstService).not_to have_received(:generate_pdf)
        expect(WeasyprintService).not_to have_received(:generate_pdf)
      end
    end

    context 'with the :dossier_vide_typst flag' do
      before do
        Flipper.enable(:dossier_vide_typst, procedure)
        allow(TypstService).to receive(:generate_pdf).and_return('%PDF-typst')
        allow(WeasyprintService).to receive(:generate_pdf).and_return('%PDF-weasyprint')
        allow(Sentry).to receive(:capture_exception)
      end

      it 'renders the Typst template from the dossier vide payload, titled with the procedure libelle' do
        expect(pdf).to eq('%PDF-typst')
        expect(TypstService).to have_received(:generate_pdf).with('dossier_vide', hash_including(title: 'Ma démarche'))
        expect(WeasyprintService).not_to have_received(:generate_pdf)
      end

      context 'but Typst failing' do
        before { allow(TypstService).to receive(:generate_pdf).and_raise(TypstService::Error, 'compiler down') }

        it 'falls back to the WeasyPrint rendering when its flag is enabled, and reports the failure' do
          Flipper.enable(:dossier_vide_weasyprint, procedure)

          expect(pdf).to eq('%PDF-weasyprint')
          expect(Sentry).to have_received(:capture_exception)
            .with(an_instance_of(TypstService::Error), extra: { procedure_id: procedure.id })
        end

        it 'falls back to the Prawn rendering otherwise' do
          expect(pdf).to start_with('%PDF-1.')
          expect(WeasyprintService).not_to have_received(:generate_pdf)
          expect(Sentry).to have_received(:capture_exception).with(an_instance_of(TypstService::Error), anything)
        end

        it 'falls back to the Prawn rendering when WeasyPrint fails in turn' do
          Flipper.enable(:dossier_vide_weasyprint, procedure)
          allow(WeasyprintService).to receive(:generate_pdf).and_raise(WeasyprintService::Error, 'service down')

          expect(pdf).to start_with('%PDF-1.')
          expect(Sentry).to have_received(:capture_exception).with(an_instance_of(TypstService::Error), anything)
          expect(Sentry).to have_received(:capture_exception).with(an_instance_of(WeasyprintService::Error), anything)
        end
      end

      it 'falls back to the Prawn rendering when the rendering raises unexpectedly' do
        allow(TypstService).to receive(:generate_pdf).and_raise(StandardError, 'boom')

        expect(pdf).to start_with('%PDF-1.')
        expect(Sentry).to have_received(:capture_exception).with(an_instance_of(StandardError), anything)
      end
    end

    context 'with the :dossier_vide_weasyprint flag alone' do
      before do
        Flipper.enable(:dossier_vide_weasyprint, procedure)
        allow(TypstService).to receive(:generate_pdf)
        allow(WeasyprintService).to receive(:generate_pdf).and_return('%PDF-weasyprint')
      end

      it 'renders the HTML component in its layout through WeasyPrint' do
        expect(pdf).to eq('%PDF-weasyprint')
        expect(WeasyprintService).to have_received(:generate_pdf)
          .with(a_string_matching(%r{<title>Ma démarche</title>}), { procedure_id: procedure.id })
        expect(TypstService).not_to have_received(:generate_pdf)
      end

      # (rendered outside a request: the URL helpers take the application host)
      it 'links an unprintable list to the online form with the application host' do
        procedure = create(:procedure, :published, :with_service, :with_path,
          public_type_de_champs: [{ type: :drop_down_list, libelle: 'Commune', options: ['Lyon', 'Paris', 'Rennes', 'Toulouse'] }])
        stub_const('Dossiers::DossierVidePdfComponent::MAX_PRINTABLE_OPTIONS', 3)
        Flipper.enable(:dossier_vide_weasyprint, procedure)

        described_class.render(procedure.published_revision)

        expect(WeasyprintService).to have_received(:generate_pdf)
          .with(a_string_including(Rails.application.routes.url_helpers.commencer_url(procedure.path)), anything)
      end
    end
  end

  describe 'caching of the published PDF' do
    before do
      Flipper.enable(:dossier_vide_typst, procedure)
      allow(TypstService).to receive(:generate_pdf).and_return('%PDF-typst')
    end

    # Each download loads the revision afresh, like a request does.
    def download = described_class.render(procedure.reload.published_revision)

    it 'generates and stores the PDF on the first download' do
      expect(download).to eq('%PDF-typst')
      expect(TypstService).to have_received(:generate_pdf).once
      expect(procedure.reload.dossier_vide_pdf).to be_attached
    end

    it 'serves the stored PDF on the next download, without rendering it again' do
      download
      allow(Typst::DossierVidePayload).to receive(:new).and_call_original

      expect(download).to eq('%PDF-typst')
      expect(TypstService).to have_received(:generate_pdf).once
      expect(Typst::DossierVidePayload).not_to have_received(:new)
    end

    it 'regenerates once the cached PDF has expired' do
      download
      procedure.reload.dossier_vide_pdf.blob.update_column(:created_at, 8.days.ago)
      download

      expect(TypstService).to have_received(:generate_pdf).twice
    end

    it 'regenerates when the presentation changes' do
      download
      procedure.update!(description: 'Une nouvelle présentation')
      download

      expect(TypstService).to have_received(:generate_pdf).twice
    end

    it 'regenerates when the service changes' do
      download
      procedure.service.update!(adresse: '2 rue de la Paix, 75002 Paris')
      download

      expect(TypstService).to have_received(:generate_pdf).twice
    end

    it 'regenerates when a new revision is published' do
      download
      procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'Un champ de plus')
      procedure.publish_revision!(procedure.administrateurs.first)
      download

      expect(TypstService).to have_received(:generate_pdf).twice
    end

    it 'does not cache anything when Typst fails' do
      allow(TypstService).to receive(:generate_pdf).and_raise(TypstService::Error)
      allow(Sentry).to receive(:capture_exception)

      expect(download).to start_with('%PDF-1.')
      expect(procedure.reload.dossier_vide_pdf).not_to be_attached
    end

    it 'keys the cache by renderer: a PDF cached by one is never served for the other' do
      allow(WeasyprintService).to receive(:generate_pdf).and_return('%PDF-weasyprint')
      download

      Flipper.disable(:dossier_vide_typst, procedure)
      Flipper.enable(:dossier_vide_weasyprint, procedure)

      expect(download).to eq('%PDF-weasyprint')
      expect(WeasyprintService).to have_received(:generate_pdf).once
    end

    it 'still serves the rendered PDF when caching it fails' do
      allow(Sentry).to receive(:capture_exception)
      allow_any_instance_of(Procedure).to receive(:store_dossier_vide_pdf).and_raise(StandardError, 'storage down')

      expect(download).to eq('%PDF-typst')
      expect(Sentry).to have_received(:capture_exception).with(an_instance_of(StandardError), anything)
      expect(procedure.reload.dossier_vide_pdf).not_to be_attached
    end

    it 'never caches the draft PDF: it is content being edited' do
      described_class.render(procedure.draft_revision)
      described_class.render(procedure.draft_revision)

      expect(TypstService).to have_received(:generate_pdf).twice
      expect(procedure.reload.dossier_vide_pdf).not_to be_attached
    end
  end

  describe '.cache_key' do
    it 'changes when the revision changes' do
      expect(described_class.cache_key(procedure.draft_revision, :typst)).not_to eq(described_class.cache_key(revision, :typst))
    end

    it 'changes when the procedure is updated' do
      before_key = described_class.cache_key(revision, :typst)
      procedure.update!(description: 'Une nouvelle présentation')

      expect(described_class.cache_key(procedure.reload.published_revision, :typst)).not_to eq(before_key)
    end

    it 'changes when the service is updated' do
      before_key = described_class.cache_key(revision, :typst)
      procedure.service.update!(adresse: '2 rue de la Paix, 75002 Paris')

      expect(described_class.cache_key(procedure.reload.published_revision, :typst)).not_to eq(before_key)
    end

    it 'changes when the cache version is bumped, which is how rendering changes are caught' do
      before_key = described_class.cache_key(revision, :typst)
      stub_const('DossierVidePdfService::CACHE_VERSION', DossierVidePdfService::CACHE_VERSION + 1)

      expect(described_class.cache_key(revision, :typst)).not_to eq(before_key)
    end

    it 'differs between renderers: the same attachment caches whichever the flags select' do
      expect(described_class.cache_key(revision, :typst)).not_to eq(described_class.cache_key(revision, :weasyprint))
    end

    it 'changes when a Typst template changes, for the Typst rendering only' do
      typst_key = described_class.cache_key(revision, :typst)
      weasyprint_key = described_class.cache_key(revision, :weasyprint)
      stub_const('DossierVidePdfService::TEMPLATES_DIGEST', 'edited-theme')

      expect(described_class.cache_key(revision, :typst)).not_to eq(typst_key)
      expect(described_class.cache_key(revision, :weasyprint)).to eq(weasyprint_key)
    end

    it 'is stable when nothing changed' do
      expect(described_class.cache_key(revision, :typst)).to eq(described_class.cache_key(revision, :typst))
    end

    it 'works for a procedure without a service' do
      procedure.update!(service: nil, organisation: 'Une organisation')

      expect(described_class.cache_key(revision, :typst)).to be_present
    end
  end
end
