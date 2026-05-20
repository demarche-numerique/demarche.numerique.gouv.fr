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

  describe '#perform with BATCH_LIMIT drainage' do
    let(:dossier_ids) { create_list(:dossier, 3).map(&:id) }
    let(:job_class) do
      ids = dossier_ids
      Class.new(described_class).tap do |klass|
        klass.define_singleton_method(:name) { 'TestDrainJob' }
        klass.define_method(:scope) { Dossier.where(id: ids) }
      end
    end

    before do
      stub_const("#{described_class}::BATCH_LIMIT", 2)
    end

    it 'processes exactly BATCH_LIMIT dossiers and re-enqueues self when more remain' do
      expect {
        job_class.perform_now
      }.to change { Dossier.where(id: dossier_ids).count }.from(3).to(1)
        .and have_enqueued_job(job_class)
    end
  end
end
