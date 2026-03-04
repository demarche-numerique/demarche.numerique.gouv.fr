# frozen_string_literal: true

RSpec.describe Attachment::AttachmentRowComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:types_de_champ_public) { [{ type: :titre_identite }] }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.champs.first }
  let(:attached_file) { champ.piece_justificative_file }
  let(:attachment) { attached_file.attachments.first }
  let(:filename) { attachment.filename.to_s }
  let(:context_kwargs) { {} }

  let(:context) do
    Attachment::Context.new(champ:, **context_kwargs)
  end

  let(:component) do
    described_class.new(attachment:, context:)
  end

  subject { render_inline(component).to_html }

  it 'renders the filename' do
    expect(subject).to have_content(filename)
  end

  it 'shows the Delete button by default' do
    expect(subject).to have_selector('[title^="Supprimer le fichier"]')
  end

  context 'when the user cannot destroy the attachment' do
    let(:context_kwargs) { { user_can_destroy: false } }

    it 'hides the Delete button' do
      expect(subject).not_to have_selector("[title^='Supprimer le fichier']")
    end
  end

  context 'when view as download' do
    let(:context_kwargs) { { view_as: :download } }

    context 'when watermarking is done' do
      before { attachment.blob.touch(:watermarked_at) }

      it 'renders a complete download interface with details to download the file' do
        expect(subject).to have_link(text: filename)
        expect(subject).to have_text(/PNG.+\d+ octets/)
      end
    end

    context 'when watermark is pending' do
      it 'displays the filename, but doesn\'t allow to download the file' do
        expect(attachment.watermark_pending?).to be_truthy
        expect(subject).to have_text(filename)
        expect(subject).to have_button('Supprimer')
        expect(subject).to have_no_link(text: filename)
      end
    end
  end

  context 'when view as link' do
    let(:context_kwargs) { { view_as: :link } }

    context 'when watermarking is done' do
      before { attachment.blob.touch(:watermarked_at) }

      it 'renders a simple link to view file' do
        expect(subject).to have_link(text: filename)
        expect(subject).not_to have_text(/PNG.+\d+ octets/)
      end
    end
  end

  context 'with non nominal or final antivirus status' do
    before do
      champ.piece_justificative_file[0].blob.update(virus_scan_result:)
    end

    context 'when the file is scanned, watermarked_at, and viewed as download and safe' do
      let(:context_kwargs) { { view_as: :download } }
      let(:virus_scan_result) { ActiveStorage::VirusScanner::SAFE }
      before { attachment.blob.touch(:watermarked_at) }

      it 'allows to download the file' do
        expect(subject).to have_link(filename)
      end
    end

    context 'when the file is scanned and infected' do
      let(:virus_scan_result) { ActiveStorage::VirusScanner::INFECTED }

      it 'displays the filename, but doesn\'t allow to download the file' do
        expect(subject).to have_text(champ.piece_justificative_file[0].filename.to_s)
        expect(subject).to have_no_link(text: filename)
        expect(subject).to have_text('Virus détecté')
      end
    end

    context 'when the file is corrupted' do
      let(:virus_scan_result) { ActiveStorage::VirusScanner::INTEGRITY_ERROR }

      it 'displays the filename, but doesn\'t allow to download the file' do
        expect(subject).to have_text(filename)
        expect(subject).to have_no_link(text: filename)
        expect(subject).to have_text('corrompu')
      end
    end
  end
end
