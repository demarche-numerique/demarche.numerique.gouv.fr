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
end
