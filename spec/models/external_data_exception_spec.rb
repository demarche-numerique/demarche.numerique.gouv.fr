# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalDataException do
  describe '#initialize' do
    it 'requires kind' do
      expect { described_class.new(error: 'boom', code: 500) }
        .to raise_error(ArgumentError, /kind/)
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
end
