# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalDataExceptionType do
  let(:type) { described_class.new }

  describe '#cast' do
    it 'returns nil for nil' do
      expect(type.cast(nil)).to be_nil
    end

    it 'parses a legacy JSON string without kind' do
      json = '{"code":500,"error":"boom"}'
      result = type.cast(json)
      expect(result.error).to eq('boom')
      expect(result.code).to eq(500)
      expect(result.kind).to be_nil
    end

    it 'parses a JSON string with kind' do
      json = '{"code":404,"error":"NotFound","kind":"not_found"}'
      result = type.cast(json)
      expect(result.kind).to eq(:not_found)
    end

    it 'parses a hash with kind symbol' do
      result = type.cast(error: 'x', code: 503, kind: :technical_error)
      expect(result.kind).to eq(:technical_error)
    end

    it 'parses a legacy hash without kind' do
      result = type.cast(error: 'x', code: 503)
      expect(result.kind).to be_nil
    end
  end

  describe '#serialize' do
    it 'serializes kind' do
      ex = ExternalDataException.new(error: 'x', code: 404, kind: :not_found)
      expect(JSON.parse(type.serialize(ex))).to eq('code' => 404, 'error' => 'x', 'kind' => 'not_found')
    end
  end
end
