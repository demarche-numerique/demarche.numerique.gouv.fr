# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalDataExceptionType do
  let(:type) { described_class.new }

  describe '#cast' do
    it 'returns nil for nil' do
      expect(type.cast(nil)).to be_nil
    end

    it 'parses a JSON string' do
      json = '{"code":500,"error":"boom"}'
      result = type.cast(json)
      expect(result.error).to eq('boom')
      expect(result.code).to eq(500)
    end

    it 'parses a hash' do
      result = type.cast(error: 'x', code: 503)
      expect(result.error).to eq('x')
      expect(result.code).to eq(503)
    end

    it 'parses a legacy hash with reason instead of error' do
      result = type.cast(reason: 'x', code: 503)
      expect(result.error).to eq('x')
    end
  end

  describe '#serialize' do
    it 'serializes error and code' do
      ex = ExternalDataException.new(error: 'x', code: 404)
      expect(JSON.parse(type.serialize(ex))).to eq('code' => 404, 'error' => 'x')
    end
  end
end
