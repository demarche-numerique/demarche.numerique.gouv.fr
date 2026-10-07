# frozen_string_literal: true

RSpec.describe AutoArchiveProcedureDossiersJob, type: :job do
  let!(:procedure) { create(:procedure, :published, :with_instructeur) }
  let!(:job) { AutoArchiveProcedureDossiersJob.new }
  before do
    procedure.auto_archive_on = 1.day.ago.to_date
    procedure.save(validate: false)
  end
  subject { job.perform(procedure) }

  context "when procedures have auto_archive_on set on yesterday or today" do
    let!(:dossier1) { create(:dossier, procedure: procedure) }
    let!(:dossier2) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:dossier3) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:dossier4) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:dossier5) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:dossier6) { create(:dossier, :accepte, procedure: procedure) }
    let!(:dossier7) { create(:dossier, :refuse, procedure: procedure) }
    let!(:dossier8) { create(:dossier, :sans_suite, procedure: procedure) }
    let!(:dossier9) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:hidden_by_user) { create(:dossier, :en_construction, :hidden_by_user, procedure: procedure) }
    let!(:hidden_by_expired) { create(:dossier, :en_construction, :hidden_by_expired, procedure: procedure) }
    let(:last_operation) { dossier2.dossier_operation_logs.last }

    before do
      dossier9.flag_as_pending_correction!(build(:commentaire))

      subject

      [dossier1, dossier2, dossier3, dossier4, dossier5, dossier6, dossier7, dossier8, dossier9, hidden_by_user, hidden_by_expired].each(&:reload)

      procedure.reload
    end

    it {
      expect(dossier1.state).to eq Dossier.states.fetch(:brouillon)
      expect(dossier2.state).to eq Dossier.states.fetch(:en_instruction)
      expect(last_operation.operation).to eq('passer_en_instruction')
      expect(last_operation.automatic_operation?).to be_truthy
      expect(dossier3.state).to eq Dossier.states.fetch(:en_instruction)
      expect(dossier4.state).to eq Dossier.states.fetch(:en_instruction)
      expect(dossier5.state).to eq Dossier.states.fetch(:en_instruction)
      expect(dossier6.state).to eq Dossier.states.fetch(:accepte)
      expect(dossier7.state).to eq Dossier.states.fetch(:refuse)
      expect(dossier8.state).to eq Dossier.states.fetch(:sans_suite)
      expect(dossier9.state).to eq Dossier.states.fetch(:en_construction)
      expect(hidden_by_user.state).to eq Dossier.states.fetch(:en_construction)
      expect(hidden_by_user).to be_hidden_by_user
      expect(hidden_by_expired.state).to eq Dossier.states.fetch(:en_construction)
    }
  end
end
