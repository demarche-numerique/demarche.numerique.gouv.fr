# frozen_string_literal: true

describe BatchOperation, type: :model do
  describe 'association' do
    it do
      is_expected.to have_many(:dossiers)
      is_expected.to belong_to(:instructeur)
      is_expected.to have_many(:dossier_operations)
    end
  end

  describe 'attributes' do
    subject { BatchOperation.new }
    it do
      expect(subject.payload).to eq({})
      expect(subject.run_at).to eq(nil)
      expect(subject.finished_at).to eq(nil)
      expect(subject.operation).to eq(nil)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:operation) }
  end

  describe '#enqueue_all' do
    context 'given dossier_ids in instructeur procedures' do
      subject do
        create(:batch_operation, :archiver, instructeur: create(:instructeur))
      end

      it 'enqueues as many BatchOperationProcessOneJob as dossiers_ids' do
        expect { subject.enqueue_all() }
          .to have_enqueued_job(BatchOperationProcessOneJob)
          .with(subject, subject.dossiers.first)
          .with(subject, subject.dossiers.second)
          .with(subject, subject.dossiers.third)
      end

      it 'pass through dossiers_safe_scope' do
        expect(subject).to receive(:dossiers_safe_scope).and_return(subject.dossiers)
        subject.enqueue_all
      end
    end
  end

  describe '#track_processed_dossier' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:simple_procedure, instructeurs: [instructeur]) }
    let(:dossier) { create(:dossier, :accepte, :with_individual, archived: true, procedure: procedure) }
    let(:batch_operation) { create(:batch_operation, operation: :archiver, instructeur: instructeur, dossiers: [dossier]) }

    it 'unlock the dossier' do
      expect { batch_operation.track_processed_dossier(true, dossier) }
        .to change { dossier.reload.batch_operation }
        .from(batch_operation)
        .to(nil)
    end

    context 'when it succeed' do
      it 'pushes dossier_job id to batch_operation.success_dossier_ids' do
        expect { batch_operation.track_processed_dossier(true, dossier) }
          .to change { batch_operation.dossier_operations.success.pluck(:dossier_id) }
          .from([])
          .to([dossier.id])
      end
    end

    context 'when it succeed after a failure' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, instructeur: instructeur, dossiers: [dossier]) }
      before do
        batch_operation.track_processed_dossier(false, dossier)
      end
      it 'remove former dossier id from failed_dossier_ids' do
        expect { batch_operation.track_processed_dossier(true, dossier) }
          .to change { batch_operation.dossier_operations.error.pluck(:dossier_id) }
          .from([dossier.id])
          .to([])
      end
    end

    context 'when it fails' do
      it 'pushes dossier_job id to batch_operation.failed_dossier_ids' do
        expect { batch_operation.track_processed_dossier(false, dossier) }
          .to change { batch_operation.dossier_operations.error.pluck(:dossier_id) }
          .from([])
          .to([dossier.id])
      end
    end

    context 'when it is the first job' do
      it 'sets run_at at first' do
        expect { batch_operation.track_processed_dossier(false, dossier) }
          .to change { batch_operation.reload.run_at }
          .from(nil)
          .to(anything)
      end
    end

    context 'when it is the second job (meaning run_at was already set) but not the last' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, instructeur: instructeur, dossiers: [dossier], run_at: 2.days.ago) }
      it 'does not change run_at' do
        expect { batch_operation.track_processed_dossier(true, dossier) }
          .not_to change { batch_operation.reload.run_at }
      end
    end

    context 'when it is the last job' do
      it 'sets finished_at' do
        expect { batch_operation.track_processed_dossier(true, dossier) }
          .to change { batch_operation.reload.finished_at }
          .from(nil)
          .to(anything)
      end
    end
  end

  describe '#dossiers_safe_scope (with archiver)' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:simple_procedure, instructeurs: [instructeur]) }
    let(:batch_operation) { create(:batch_operation, operation: :archiver, instructeur: instructeur, dossiers: [dossier]) }

    context 'when dossier is valid' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, procedure: procedure) }

      it 'find dosssier' do
        expect(batch_operation.dossiers_safe_scope).to include(dossier)
      end
    end
    context 'when dossier is already archived' do
      let(:dossier) { create(:dossier, :archived, :with_individual, procedure: procedure) }

      it 'skips dossier is already archived' do
        expect(batch_operation.dossiers_safe_scope).not_to include(dossier)
      end
    end

    context 'when dossier is not in state termine' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }

      it 'does not enqueue any job' do
        expect(batch_operation.dossiers_safe_scope).not_to include(dossier)
      end
    end

    context 'when dossier is not in instructeur procedures' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, procedure: create(:simple_procedure)) }

      it 'does not enqueues any BatchOperationProcessOneJob' do
        expect(batch_operation.dossiers_safe_scope).not_to include(dossier)
      end
    end
  end

  describe '#dossiers_safe_scope (with passer_en_instruction)' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:simple_procedure, instructeurs: [instructeur]) }
    let(:batch_operation) { create(:batch_operation, operation: :passer_en_instruction, instructeur: instructeur, dossiers: [dossier]) }

    context 'when dossier is valid' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: procedure) }

      it 'find dosssier' do
        expect(batch_operation.dossiers_safe_scope).to include(dossier)
      end
    end

    context 'when dossier is already en instruction' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }

      it 'skips dossier is already en instruction' do
        expect(batch_operation.dossiers_safe_scope).not_to include(dossier)
      end
    end

    context 'when dossier is not in state en construction' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, procedure: procedure) }

      it 'does not enqueue any job' do
        expect(batch_operation.dossiers_safe_scope).not_to include(dossier)
      end
    end
  end

  describe '#dossiers_safe_scope (with accepter)' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:simple_procedure, instructeurs: [instructeur]) }
    let(:batch_operation) { create(:batch_operation, operation: :accepter, instructeur: instructeur, dossiers: [dossier]) }

    context 'when dossier is valid' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }

      it 'find dosssier' do
        expect(batch_operation.dossiers_safe_scope).to include(dossier)
      end
    end

    context 'when dossier is already accepte' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, procedure: procedure) }

      it 'skips dossier is already en instruction' do
        expect(batch_operation.dossiers_safe_scope).not_to include(dossier)
      end
    end

    context 'when dossier is not in state en instruction' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: procedure) }

      it 'does not enqueue any job' do
        expect(batch_operation.dossiers_safe_scope).not_to include(dossier)
      end
    end
  end

  describe '#safe_create!' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:simple_procedure, instructeurs: [instructeur]) }
    let(:dossier_2) { create(:dossier, :accepte, procedure: procedure) }
    subject { BatchOperation.safe_create!(instructeur: instructeur, operation: :archiver, dossier_ids: [dossier.id, dossier_2.id]) }

    context 'success with divergent list of dossier_ids' do
      let(:dossier) { create(:dossier, :archived, :with_individual, procedure: procedure) }

      it 'does not keep archived dossier within batch_operation.dossiers' do
        expect(subject.dossiers).not_to include(dossier)
      end

      it 'enqueue a BatchOperationEnqueueAllJob' do
        expect { subject }.to have_enqueued_job(BatchOperationEnqueueAllJob)
      end
    end

    context 'with dossier already in a batch batch_operation' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, batch_operation: create(:batch_operation, :archiver, instructeur: instructeur), procedure: procedure) }

      it 'does not keep dossier in batch_operation' do
        expect(subject.dossiers).not_to include(dossier)
      end
    end
  end

  describe '#process_one' do
    let(:dossier) { create(:dossier, :en_instruction, :with_individual) }
    subject { create(:batch_operation, operation, instructeur: create(:instructeur)) }

    context 'accepter' do
      let(:operation) { :accepter }
      it { expect { subject.process_one(dossier) }.to have_enqueued_job(PriorizedMailDeliveryJob) }
    end

    context 'refuser' do
      let(:operation) { :refuser }
      it { expect { subject.process_one(dossier) }.to have_enqueued_job(PriorizedMailDeliveryJob) }
    end

    context 'classer_sans_suite' do
      let(:operation) { :classer_sans_suite }
      it { expect { subject.process_one(dossier) }.to have_enqueued_job(PriorizedMailDeliveryJob) }
    end
  end

  describe 'stale' do
    let(:finished_at) { 6.hours.ago }
    let(:staled_batch_operation) { create(:batch_operation, operation: :archiver, finished_at: 2.days.ago, updated_at: 2.days.ago) }
    it 'finds stale jobs' do
      expect(BatchOperation.stale).to match_array(staled_batch_operation)
    end
  end

  describe 'stuck' do
    let(:stuck_batch_operation) { create(:batch_operation, operation: :archiver, finished_at: nil, updated_at: 2.days.ago) }
    it 'finds stale jobs' do
      expect(BatchOperation.stuck).to match_array(stuck_batch_operation)
    end
  end
end
