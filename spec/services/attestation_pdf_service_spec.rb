# frozen_string_literal: true

describe AttestationPdfService do
  let(:dossier) { dossiers.accepte }
  let(:procedure) { dossier.procedure }
  let(:attestation_template) { create(:attestation_template, :v2, procedure:) }

  subject(:pdf) { described_class.render(attestation_template, dossier:, context: { dossier_id: dossier.id }) }

  before do
    allow(WeasyprintService).to receive(:generate_pdf).and_return('%PDF-weasyprint')
    allow(TypstService).to receive(:generate_pdf).and_return('%PDF-typst')
  end

  context 'v1 template' do
    let(:attestation_template) { create(:attestation_template, procedure:, title: 'Attestation v1') }

    it 'renders the Prawn template' do
      expect(pdf).to start_with('%PDF-1.')
      expect(WeasyprintService).not_to have_received(:generate_pdf)
      expect(TypstService).not_to have_received(:generate_pdf)
    end
  end

  context 'without the attestation_typst flag' do
    it 'renders the HTML template through WeasyPrint, with the request context' do
      expect(pdf).to eq('%PDF-weasyprint')
      expect(WeasyprintService).to have_received(:generate_pdf)
        .with(a_string_matching(/Mon titre pour #{procedure.libelle}.+n° #{dossier.id}/m), { procedure_id: procedure.id, dossier_id: dossier.id })
      expect(TypstService).not_to have_received(:generate_pdf)
    end

    it 'leaves a WeasyPrint failure to the caller' do
      allow(WeasyprintService).to receive(:generate_pdf).and_raise(WeasyprintService::Error, 'service down')

      expect { pdf }.to raise_error(WeasyprintService::Error)
    end
  end

  context 'with the attestation_typst flag on the procedure' do
    before { Flipper.enable(:attestation_typst, procedure) }

    it 'renders the Typst template from the attestation payload, in the root of its assets' do
      expect(pdf).to eq('%PDF-typst')
      expect(TypstService).to have_received(:generate_pdf)
        .with('attestation', hash_including(title: "Mon titre pour #{procedure.libelle}"), assets: an_instance_of(TypstService::Assets))
      expect(WeasyprintService).not_to have_received(:generate_pdf)
    end

    it 'previews without a dossier, with the signature of a groupe instructeur' do
      groupe_instructeur = procedure.defaut_groupe_instructeur
      groupe_instructeur.signature.attach(io: Rails.root.join('spec/fixtures/files/black.png').open, filename: 'black.png', content_type: 'image/png')

      described_class.render(attestation_template, groupe_instructeur:)

      expect(TypstService).to have_received(:generate_pdf)
        .with('attestation', hash_including(title: 'Mon titre pour --dossier_procedure_libelle--', signature: { path: '/assets/1.png', alt: 'Signature' }), assets: anything)
    end

    it 'falls back to WeasyPrint when the Typst rendering fails, reporting the error with the context' do
      allow(TypstService).to receive(:generate_pdf).and_raise(TypstService::Error, 'compiler down')
      allow(Sentry).to receive(:capture_exception)

      expect(pdf).to eq('%PDF-weasyprint')
      expect(Sentry).to have_received(:capture_exception).with(an_instance_of(TypstService::Error), extra: { procedure_id: procedure.id, dossier_id: dossier.id })
    end
  end
end
