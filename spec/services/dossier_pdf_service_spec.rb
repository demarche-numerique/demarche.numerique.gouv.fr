# frozen_string_literal: true

describe DossierPdfService do
  let(:dossier) { dossiers.en_construction }
  let(:acls) { PiecesJustificativesService.new(user_profile: dossier.user, export_template: nil).acl_for_dossier_export(dossier.procedure) }

  subject(:pdf) { described_class.render(dossier, acls:) }

  context 'without the dossier_pdf_typst flag' do
    it 'renders the Prawn template' do
      expect(TypstService).not_to receive(:generate_pdf)

      expect(pdf).to start_with('%PDF-1.')
    end
  end

  context 'with the dossier_pdf_typst flag on the procedure' do
    before { Flipper.enable(:dossier_pdf_typst, dossier.procedure) }
    after { Flipper.disable(:dossier_pdf_typst, dossier.procedure) }

    it 'renders the Typst template from the dossier payload' do
      pdf

      expect(TypstService).to have_received(:generate_pdf).with('dossier', hash_including(title: "Dossier n° #{dossier.id}", form: hash_including(title: 'Formulaire')), assets: an_instance_of(TypstService::Assets))
    end

    it 'falls back to the Prawn template when the Typst rendering fails, reporting the error' do
      allow(TypstService).to receive(:generate_pdf).and_raise(TypstService::Error, 'PDF generation failed')
      allow(Sentry).to receive(:capture_exception)

      expect(pdf).to start_with('%PDF-1.')
      expect(Sentry).to have_received(:capture_exception).with(an_instance_of(TypstService::Error), extra: { dossier_id: dossier.id })
    end
  end
end
