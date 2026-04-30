# frozen_string_literal: true

RSpec.describe Attachment::ThumbnailComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
  let(:dossier) { create(:dossier, :en_construction, procedure:) }
  let(:champ_pj) { dossier.champs.first }
  let(:attachment) do
    champ_pj.piece_justificative_file.attach(
      io: file,
      filename:,
      content_type: file.content_type,
      metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
    )
    champ_pj.piece_justificative_file.attachments.first
  end
  let(:filename) { file.original_filename }
  let(:component) { described_class.new(attachment:) }

  subject { render_inline(component) }

  context "when attachment is from a piece justificative champ" do
    let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }
    let(:libelle) { champ_pj.libelle }

    it do
      expect(subject).to have_css("a[title='Visualiser #{libelle} -- #{filename}']")
    end

    context 'when the blob is infected' do
      before { attachment.blob.update!(virus_scan_result: ActiveStorage::VirusScanner::INFECTED) }

      it 'does not render the gallery link' do
        expect(subject).not_to have_css('a.lightGalleryLink')
        expect(subject).to have_text('Aperçu non disponible')
      end
    end
  end
end
