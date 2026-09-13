# frozen_string_literal: true

RSpec.describe Cron::AutoArchiveProcedureJob, type: :job do
  let!(:procedure) { create(:procedure, :published, :with_instructeur, auto_archive_on: nil) }
  let!(:procedure_hier) { create(:procedure, :published, :with_instructeur) }
  let!(:procedure_aujourdhui) { create(:procedure, :published, :with_instructeur) }
  let!(:procedure_demain) { create(:procedure, :published, :with_instructeur, auto_archive_on: 1.day.from_now.to_date) }
  let!(:job) { Cron::AutoArchiveProcedureJob.new }

  before do
    procedure_hier.auto_archive_on = 1.day.ago.to_date
    procedure_hier.save!(validate: false)
    procedure_aujourdhui.auto_archive_on = Date.current
    procedure_aujourdhui.save!(validate: false)
  end

  subject { job.perform }

  context "when procedures have no auto_archive_on" do
    before do
      subject
      procedure.reload
    end

    it { expect(procedure.close?).to eq false }
  end

  context "when procedures have auto_archive_on set on yesterday or today" do
    let!(:dossier1) { create(:dossier, procedure: procedure_hier) }
    let!(:dossier2) { create(:dossier, :en_construction, procedure: procedure_hier) }
    let!(:dossier3) { create(:dossier, :en_construction, procedure: procedure_hier) }
    let!(:dossier4) { create(:dossier, :en_construction, procedure: procedure_hier) }
    let!(:dossier5) { create(:dossier, :en_instruction, procedure: procedure_hier) }
    let!(:dossier6) { create(:dossier, :accepte, procedure: procedure_hier) }
    let!(:dossier7) { create(:dossier, :refuse, procedure: procedure_hier) }
    let!(:dossier8) { create(:dossier, :sans_suite, procedure: procedure_hier) }
    let!(:dossier9) { create(:dossier, :en_construction, procedure: procedure_aujourdhui) }
    let(:last_operation) { dossier2.dossier_operation_logs.last }

    before do
      subject

      [dossier1, dossier2, dossier3, dossier4, dossier5, dossier6, dossier7, dossier8, dossier9].each(&:reload)

      procedure_hier.reload
      procedure_aujourdhui.reload
    end

    it {
      expect(procedure_hier.close?).to eq true
      expect(procedure_aujourdhui.close?).to eq true
    }
  end

  context "when procedures have auto_archive_on set on future" do
    before do
      subject
    end

    it { expect(procedure_demain.close?).to eq false }
  end

  context 'when an error occurs' do
    let!(:buggy_procedure) { create(:procedure, :published, :with_instructeur) }

    before do
      buggy_procedure.auto_archive_on = 1.day.ago.to_date
      buggy_procedure.save!(validate: false)

      error = StandardError.new('nop')
      expect(buggy_procedure).to receive(:close!).and_raise(error)
      expect(job).to receive(:procedures_to_close).and_return([buggy_procedure, procedure_hier])
      expect(Sentry).to receive(:capture_exception).with(error, tags: { procedure: buggy_procedure.id })

      subject
    end

    it "should close all the procedure" do
      expect(procedure_hier.reload.close?).to eq true
    end
  end
end
