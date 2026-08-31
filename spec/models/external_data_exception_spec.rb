# frozen_string_literal: true

RSpec.describe ExternalDataException do
  describe '#definitive?' do
    [404, 422, 451].each do |code|
      it "is true for #{code}" do
        expect(described_class.new(error: 'boom', code:)).to be_definitive
      end
    end

    [429, 500, 503, nil].each do |code|
      it "is false for #{code.inspect}" do
        expect(described_class.new(error: 'boom', code:)).not_to be_definitive
      end
    end
  end
end
