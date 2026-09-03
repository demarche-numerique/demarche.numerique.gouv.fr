# frozen_string_literal: true

describe ChampPresentations::MultilineTextPresentation do
  let(:text) { "Première ligne\r\nDeuxième ligne\n\nAprès un saut\n" }
  let(:presentation) { described_class.new(text) }

  describe '#to_s' do
    it 'returns the text with normalized line breaks' do
      expect(presentation.to_s).to eq("Première ligne\nDeuxième ligne\n\nAprès un saut")
    end

    it { expect(described_class.new(nil).to_s).to eq('') }
  end

  describe '#to_tiptap_nodes' do
    it 'returns a text node per line separated by hard breaks' do
      expect(presentation.to_tiptap_nodes).to eq([
        { type: 'text', text: 'Première ligne' },
        { type: 'hardBreak' },
        { type: 'text', text: 'Deuxième ligne' },
        { type: 'hardBreak' },
        { type: 'hardBreak' },
        { type: 'text', text: 'Après un saut' },
      ])
    end

    it { expect(described_class.new(nil).to_tiptap_nodes).to eq([]) }
  end
end
