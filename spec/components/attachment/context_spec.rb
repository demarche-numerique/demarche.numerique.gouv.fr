# frozen_string_literal: true

RSpec.describe Attachment::Context do
  describe '#initialize' do
    it 'rejects invalid view_as' do
      expect { described_class.new(view_as: :invalid) }
        .to raise_error(ArgumentError, /Invalid view_as/)
    end
  end

  describe '#downloadable?' do
    it 'returns true for :download, false for :link' do
      expect(described_class.new(view_as: :download).downloadable?).to be true
      expect(described_class.new(view_as: :link).downloadable?).to be false
    end
  end

  describe '#for_champ?' do
    it 'returns true when champ is present, false otherwise' do
      champ = double('champ', piece_justificative_file: nil)
      expect(described_class.new(champ:).for_champ?).to be true
      expect(described_class.new(champ: nil).for_champ?).to be false
    end
  end
end
