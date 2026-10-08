# frozen_string_literal: true

RSpec.describe Cron::ProcedureProcessSVASVRJob, type: :job do
  before_all { seed "cases/sva" }

  let!(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, depose_at: 2.months.ago, sva_svr_decision_on: Date.current) }
  let!(:dossier_in_future) { create(:dossier, :en_instruction, :with_individual, procedure:, depose_at: 1.day.ago, sva_svr_decision_on: Date.yesterday + 2.months) }
  let!(:dossier_en_construction) { create(:dossier, :en_construction, :with_individual, procedure:, depose_at: 2.months.ago, sva_svr_decision_on: Date.current) }
  let!(:dossier_en_brouillon) { create(:dossier, :brouillon, :with_individual, procedure:) }
  let!(:dossier_without_date) { create(:dossier, :en_instruction, :with_individual, procedure:, depose_at: 2.months.ago) }

  subject(:perform_job) { described_class.perform_now }
  before { perform_job }

  context 'when procedure is published' do
    let(:procedure) { procedures.sva }

    it 'queues ProcedureSVASVRProcessDossierJob for the dated dossiers of a published sva procedure' do
      expect(ProcedureSVASVRProcessDossierJob).to have_been_enqueued.with(dossier)
      expect(ProcedureSVASVRProcessDossierJob).to have_been_enqueued.with(dossier_en_construction)
      expect(ProcedureSVASVRProcessDossierJob).to have_been_enqueued.with(dossier_in_future)
      expect(ProcedureSVASVRProcessDossierJob).to have_been_enqueued.exactly(3).times
    end
  end

  context 'when procedure is closed' do
    let(:procedure) { create(:procedure, :closed, :sva, :for_individual) }

    it { expect(ProcedureSVASVRProcessDossierJob).to have_been_enqueued.with(dossier) }
  end

  context 'when the rule is disabled' do
    let(:procedure) { procedures.sva }

    subject(:perform_job) do
      procedure.update_column(:sva_svr, procedure.sva_svr.merge('disabled_at' => Time.current.iso8601))
      described_class.perform_now
    end

    it 'keeps processing the dossiers the rule already dated' do
      expect(ProcedureSVASVRProcessDossierJob).to have_been_enqueued.exactly(3).times
    end
  end

  context 'when procedure is not sva' do
    let(:procedure) { create(:procedure, :published, :for_individual) }

    it { expect(ProcedureSVASVRProcessDossierJob).not_to have_been_enqueued }
  end
end
