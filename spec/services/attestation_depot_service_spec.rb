# frozen_string_literal: true

describe AttestationDepotService do
  let(:dossier) { dossiers.en_construction }

  subject(:pdf) { described_class.render(dossier) }

  before do
    allow(WeasyprintService).to receive(:generate_pdf).and_return('%PDF-weasyprint')
    allow(TypstService).to receive(:generate_pdf).and_return('%PDF-typst')
  end

  context 'without the attestation_depot_typst flag' do
    it 'renders the HTML template through WeasyPrint' do
      expect(pdf).to eq('%PDF-weasyprint')
      expect(WeasyprintService).to have_received(:generate_pdf)
        .with(a_string_matching(/#{dossier.procedure.libelle}/), { procedure_id: dossier.procedure.id, dossier_id: dossier.id })
      expect(TypstService).not_to have_received(:generate_pdf)
    end
  end

  context 'with the attestation_depot_typst flag on the procedure' do
    before { Flipper.enable(:attestation_depot_typst, dossier.procedure) }

    it 'renders the Typst template from the attestation payload' do
      expect(pdf).to eq('%PDF-typst')
      expect(TypstService).to have_received(:generate_pdf)
        .with('attestation_depot', hash_including(procedure: dossier.procedure.libelle))
      expect(WeasyprintService).not_to have_received(:generate_pdf)
    end

    it 'falls back to WeasyPrint when the Typst rendering fails, reporting the error' do
      allow(TypstService).to receive(:generate_pdf).and_raise(TypstService::Error, 'compiler down')
      allow(Sentry).to receive(:capture_exception)

      expect(pdf).to eq('%PDF-weasyprint')
      expect(Sentry).to have_received(:capture_exception).with(an_instance_of(TypstService::Error), extra: { dossier_id: dossier.id })
    end

    it 'leaves a WeasyPrint failure to the caller' do
      allow(WeasyprintService).to receive(:generate_pdf).and_raise(WeasyprintService::Error, 'service down')
      Flipper.disable(:attestation_depot_typst, dossier.procedure)

      expect { pdf }.to raise_error(WeasyprintService::Error)
    end
  end
end
