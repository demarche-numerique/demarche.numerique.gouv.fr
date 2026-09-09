# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalDataException do
  describe '#not_found?' do
    it 'is true when code is 404' do
      expect(described_class.new(error: 'boom', code: 404).not_found?).to be_truthy
    end

    it 'is false for a technical error code' do
      expect(described_class.new(error: 'boom', code: 503).not_found?).to be_falsey
    end

    it 'is false without code' do
      expect(described_class.new(error: 'boom', code: nil).not_found?).to be_falsey
    end
  end

  describe '#definitive?' do
    [404, 422, 451].each do |code|
      it "is true for #{code}, the API will not answer differently later" do
        expect(described_class.new(error: 'boom', code:).definitive?).to be_truthy
      end
    end

    [429, 500, 503].each do |code|
      it "is false for #{code}, a retry or a backfill can still succeed" do
        expect(described_class.new(error: 'boom', code:).definitive?).to be_falsey
      end
    end

    it 'is false without code' do
      expect(described_class.new(error: 'boom', code: nil).definitive?).to be_falsey
    end
  end
end
