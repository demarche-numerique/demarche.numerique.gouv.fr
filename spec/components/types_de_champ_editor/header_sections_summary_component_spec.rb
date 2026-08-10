# frozen_string_literal: true

describe TypesDeChampEditor::HeaderSectionsSummaryComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private:) }
  let(:types_de_champ_private) { [] }

  subject { render_inline(described_class.new(procedure:, is_private:)) }

  context 'public types de champ' do
    let(:is_private) { false }
    let(:types_de_champ_public) do
      [
        { type: :header_section, level: 1, libelle: 's1' },
        { type: :text, libelle: 't1' },
        { type: :header_section, level: 2, libelle: 's1.1' },
        { type: :header_section, level: 3, libelle: 's1.1.1' },
        { type: :repetition, libelle: 'rep', children: [{ type: :header_section, level: 1, libelle: 'rs1' }] },
        { type: :header_section, level: 1, libelle: 's2' },
      ]
    end

    it 'renders header sections and repetitions with their depth' do
      expect(subject).to have_selector("a", text: /\As1\z/)
      expect(subject).to have_selector("a", text: '-- s1.1')
      expect(subject).to have_selector("a.custom-link-grey", text: '-- s1.1.1')
      expect(subject).to have_selector("a.custom-link-grey", text: '-- rep')
      expect(subject).to have_selector("a.custom-link-grey", text: '-- rs1')
      expect(subject).to have_selector("a", text: /\As2\z/)
      expect(subject).not_to have_text('t1')
    end

    it 'anchors links to the editor coordinates' do
      ['s1', 'rep', 'rs1'].each do |libelle|
        coordinate = procedure.draft_revision.revision_types_de_champ.find { it.libelle == libelle }
        expect(subject).to have_selector("a[href='##{ActionView::RecordIdentifier.dom_id(coordinate, :type_de_champ_editor)}']")
      end
    end
  end

  context 'private types de champ' do
    let(:is_private) { true }
    let(:types_de_champ_public) { [{ type: :header_section, level: 1, libelle: 's1' }] }
    let(:types_de_champ_private) do
      [
        { type: :header_section, level: 1, libelle: 'ps1' },
        { type: :text, libelle: 'pt1' },
      ]
    end

    it 'only renders private header sections' do
      expect(subject).to have_selector("a", text: 'ps1')
      expect(subject).not_to have_text(/\As1\z/)
    end
  end

  context 'without header sections' do
    let(:is_private) { false }
    let(:types_de_champ_public) { [{ type: :text, libelle: 't1' }] }

    it 'renders no sidemenu' do
      expect(subject).not_to have_selector("nav")
    end
  end
end
