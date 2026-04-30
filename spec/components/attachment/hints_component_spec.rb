# frozen_string_literal: true

RSpec.describe Attachment::HintsComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }
  let(:attached_file) { champ.piece_justificative_file }

  let(:component) do
    described_class.new(champ:, attached_file:)
  end

  subject { render_inline(component).to_html }

  context 'when champ is a piece_justificative with titre_identite nature' do
    let(:types_de_champ_public) { [{ type: :piece_justificative, nature: 'titre_identite' }] }

    it 'renders exhaustive format list without tooltip' do
      expect(subject).to have_content('.jpg, .jpeg, .png')
      expect(subject).to have_no_selector('[role="tooltip"]')
    end
  end

  context 'when champ is a piece_justificative with RIB nature' do
    let(:types_de_champ_public) { [{ type: :piece_justificative, nature: 'rib' }] }

    it 'renders exhaustive format list without tooltip' do
      expect(subject).to have_content('.pdf, .doc, .docx, .jpg, .jpeg, .png')
      expect(subject).to have_no_selector('[role="tooltip"]')
    end
  end

  context 'when champ is a piece_justificative with all families selected' do
    let(:types_de_champ_public) { [{ type: :piece_justificative }] }

    before do
      champ.type_de_champ.update!(options: champ.type_de_champ.options.merge(
        pj_limit_formats: true,
        pj_format_families: FORMAT_FAMILIES.keys.map(&:to_s)
      ))
    end

    it 'does not display format information' do
      expect(subject).to have_no_content('Formats acceptés')
    end
  end

  context 'when champ is a piece_justificative limited to document_texte' do
    let(:types_de_champ_public) { [{ type: :piece_justificative }] }

    before do
      champ.type_de_champ.update!(options: champ.type_de_champ.options.merge(
        pj_limit_formats: true,
        pj_format_families: ['document_texte']
      ))
    end

    it 'renders format info with category name and top formats' do
      expect(subject).to have_content('document texte (.pdf, .docx...)')
    end

    it 'renders tooltip with full format list' do
      expect(subject).to have_selector('[role="tooltip"]')
    end
  end

  context 'when champ is a piece_justificative with no format limit' do
    let(:types_de_champ_public) { [{ type: :piece_justificative }] }

    it 'does not render format info' do
      expect(subject).to have_no_content('Formats acceptés')
    end
  end
end
