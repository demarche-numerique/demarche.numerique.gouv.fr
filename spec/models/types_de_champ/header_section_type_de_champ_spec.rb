# frozen_string_literal: true

describe TypesDeChamp::HeaderSectionTypeDeChamp do
  describe '#check_coherent_header_level' do
    let(:header) { described_class.new(header_section_level: 3) }
    let(:upper_tdcs) { [described_class.new(header_section_level: 1)] }

    it 'names the missing level' do
      expect(header.check_coherent_header_level(upper_tdcs)).to eq("devrait être précédé d’un titre de niveau 2")
    end
  end
end
