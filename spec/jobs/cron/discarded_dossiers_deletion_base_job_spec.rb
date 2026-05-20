# frozen_string_literal: true

RSpec.describe Cron::DiscardedDossiersDeletionBaseJob, type: :job do
  describe '#perform' do
    it 'raises NotImplementedError when scope is not overridden' do
      expect { described_class.new.perform }.to raise_error(NotImplementedError)
    end
  end

  describe 'BATCH_LIMIT constant' do
    it 'is set to 100' do
      expect(described_class::BATCH_LIMIT).to eq(100)
    end
  end
end
