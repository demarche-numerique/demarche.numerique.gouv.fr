# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalDataException do
  describe '#initialize' do
    it 'defaults kind to nil' do
      ex = described_class.new(error: 'boom', code: 500)
      expect(ex.kind).to be_nil
    end

    it 'accepts :not_found' do
      ex = described_class.new(error: 'boom', code: 404, kind: :not_found)
      expect(ex.kind).to eq(:not_found)
    end

    it 'accepts :technical_error' do
      ex = described_class.new(error: 'boom', code: 503, kind: :technical_error)
      expect(ex.kind).to eq(:technical_error)
    end
  end

  describe 'KINDS' do
    it { expect(described_class::KINDS).to contain_exactly(:not_found, :technical_error) }
  end

  describe '#not_found?' do
    it 'is true when code is 404 (legacy exceptions without kind)' do
      expect(described_class.new(error: 'boom', code: 404).not_found?).to be_truthy
    end

    it 'is true when kind is :not_found even without a 404 code' do
      expect(described_class.new(error: 'boom', code: nil, kind: :not_found).not_found?).to be_truthy
    end

    it 'is false for a technical error' do
      expect(described_class.new(error: 'boom', code: 503, kind: :technical_error).not_found?).to be_falsey
    end
  end
end
