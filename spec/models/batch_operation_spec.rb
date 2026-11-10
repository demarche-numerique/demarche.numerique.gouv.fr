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

      it 'sets run_at' do
        expect { subject.enqueue_all }
          .to change { subject.reload.run_at }
          .from(nil)
          .to(anything)
      end
    end
  end

  describe '#finalize_if_complete!' do
    let(:instructeur) { instructeurs.default }
    let(:procedure) { procedures.individual }
    let(:dossier) { create(:dossier, :accepte, :with_individual, archived: true, procedure: procedure) }
    let(:batch_operation) { create(:batch_operation, operation: :archiver, instructeur: instructeur, dossiers: [dossier]) }

    context 'when dossiers remain' do
      it 'does not set finished_at' do
        expect { batch_operation.finalize_if_complete! }
          .not_to change { batch_operation.reload.finished_at }
      end
    end

    context 'when all dossiers are processed' do
      before { batch_operation.dossiers.delete_all }

      it 'sets finished_at' do
        expect { batch_operation.finalize_if_complete! }
          .to change { batch_operation.reload.read_attribute(:finished_at) }
          .from(nil)
          .to(anything)
      end

      it 'is idempotent (only one caller wins)' do
        batch_operation.finalize_if_complete!
        finished_at = batch_operation.reload.read_attribute(:finished_at)

        expect { batch_operation.finalize_if_complete! }
          .not_to change { batch_operation.reload.read_attribute(:finished_at) }
          .from(finished_at)
      end
    end
  end

  describe '#track_processed_dossier' do
    let(:instructeur) { instructeurs.default }
    let(:procedure) { procedures.individual }
    let(:dossier) { create(:dossier, :accepte, :with_individual, archived: true, procedure: procedure) }
    let(:batch_operation) { create(:batch_operation, operation: :archiver, instructeur: instructeur, dossiers: [dossier]) }

    it 'unlock the dossier' do
      expect { batch_operation.track_processed_dossier(true, dossier, nil) }
        .to change { dossier.reload.batch_operation }
        .from(batch_operation)
        .to(nil)
    end

    context 'when it succeed' do
      it 'pushes dossier_job id to batch_operation.success_dossier_ids' do
        expect { batch_operation.track_processed_dossier(true, dossier, nil) }
          .to change { batch_operation.dossier_operations.success.pluck(:dossier_id) }
          .from([])
          .to([dossier.id])
      end
    end

    context 'when it succeed after a failure' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, instructeur: instructeur, dossiers: [dossier]) }
      before do
        batch_operation.track_processed_dossier(false, dossier, nil)
      end
      it 'remove former dossier id from failed_dossier_ids' do
        expect { batch_operation.track_processed_dossier(true, dossier, nil) }
          .to change { batch_operation.dossier_operations.error.pluck(:dossier_id) }
          .from([dossier.id])
          .to([])
      end
    end

    context 'when it fails' do
      it 'pushes dossier_job id to batch_operation.failed_dossier_ids' do
        expect { batch_operation.track_processed_dossier(false, dossier, nil) }
          .to change { batch_operation.dossier_operations.error.pluck(:dossier_id) }
          .from([])
          .to([dossier.id])
      end
    end

    context 'when a duplicate job already processed the dossier' do
      subject(:dossier_operation) { batch_operation.dossier_operations.find_by!(dossier:) }

      before { batch_operation.track_processed_dossier(true, dossier, nil) }

      it 'keeps the success state on a duplicate success' do
        expect { batch_operation.track_processed_dossier(true, dossier, nil) }
          .not_to change { dossier_operation.reload.state }
          .from('success')
      end

      it 'keeps the success state on a duplicate failure' do
        expect { batch_operation.track_processed_dossier(false, dossier, 'boom') }
          .not_to change { dossier_operation.reload.state }
          .from('success')
        expect(dossier_operation.error_message).to be_nil
      end
    end
  end

  describe '#dossiers_safe_scope (with archiver)' do
    let(:instructeur) { instructeurs.default }
    let(:procedure) { procedures.individual }
    let(:batch_operation) { create(:batch_operation, operation: :archiver, instructeur: instructeur, dossiers: [dossier]) }

    context 'when dossier is valid' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, procedure: procedure) }

      it 'find dosssier' do
        expect(batch_operation.dossiers_safe_scope).to include(dossier)
      end
    end
    context 'when dossier is already archived' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, archived: true, procedure: procedure) }

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

  describe '#dossiers_safe_scope (with create_avis)' do
    let(:procedure) { procedures.individual }
    let(:dossier) { dossiers.en_instruction }
    let(:batch_operation) { create(:batch_operation, operation: :create_avis, instructeur: instructeurs.default, dossiers: [dossier]) }

    context 'when the procedure allows expert review' do
      it { expect(batch_operation.dossiers_safe_scope).to include(dossier) }
    end

    context 'when the procedure disallows expert review' do
      before { procedure.update!(allow_expert_review: false) }

      it { expect(batch_operation.dossiers_safe_scope).not_to include(dossier) }
    end

    context 'when the dossier is termine' do
      let(:dossier) { dossiers.accepte }

      it { expect(batch_operation.dossiers_safe_scope).not_to include(dossier) }
    end
  end

  describe '#after_all_processed (with create_avis)' do
    let(:instructeur) { create(:instructeur) }
    let(:batch_operation) do
      create(:batch_operation, :create_avis, instructeur:, emails: ['nouvelle-experte@exemple.fr'], introduction: 'Merci')
    end
    let(:dossier) { batch_operation.dossiers.first }
    let!(:previous_avis) { create(:avis, dossier:, claimant: instructeur, created_at: 1.year.ago) }

    before do
      allow(AvisMailer).to receive(:avis_invitation_and_confirm_email).and_call_original
      batch_operation.dossiers.each { BatchOperationProcessOneJob.perform_now(batch_operation, it) }
    end

    it 'invites only the experts asked by this batch' do
      new_expert_user = User.find_by!(email: 'nouvelle-experte@exemple.fr')

      expect(AvisMailer).to have_received(:avis_invitation_and_confirm_email).once
      expect(AvisMailer).to have_received(:avis_invitation_and_confirm_email)
        .with(new_expert_user, anything, match_array(new_expert_user.expert.avis))
    end
  end

  describe '#dossiers_safe_scope (with passer_en_instruction)' do
    let(:instructeur) { instructeurs.default }
    let(:procedure) { procedures.individual }
    let(:batch_operation) { create(:batch_operation, operation: :passer_en_instruction, instructeur: instructeur, dossiers: [dossier]) }

    context 'when dossier is valid' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: procedure) }

      it 'find dosssier' do
        expect(batch_operation.dossiers_safe_scope).to include(dossier)
      end
    end

    context 'when dossier is already en instruction' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, archived: true, procedure: procedure) }

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
    let(:instructeur) { instructeurs.default }
    let(:procedure) { procedures.individual }
    let(:batch_operation) { create(:batch_operation, operation: :accepter, instructeur: instructeur, dossiers: [dossier]) }

    context 'when dossier is valid' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }

      it 'find dosssier' do
        expect(batch_operation.dossiers_safe_scope).to include(dossier)
      end
    end

    context 'when dossier is already accepte' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, archived: true, procedure: procedure) }

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
    let(:instructeur) { instructeurs.default }
    let(:procedure) { procedures.individual }
    let(:dossier_2) { create(:dossier, :accepte, procedure: procedure) }
    subject { BatchOperation.safe_create!(instructeur: instructeur, operation: :archiver, dossier_ids: [dossier.id, dossier_2.id]) }

    context 'success with divergent list of dossier_ids' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, archived: true, procedure: procedure) }

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

    context 'with a dossier that is invalid at rest' do
      let(:dossier) { dossiers.accepte }

      before { Individual.where(dossier:).delete_all }

      it 'still attaches the dossier to the batch' do
        expect(subject.dossiers).to include(dossier)
        expect(dossier.reload.batch_operation).to eq(subject)
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

    context 'create_commentaire' do
      let(:operation) { :create_commentaire }
      let(:dossier) { create(:dossier, :en_construction, :with_individual) }

      before do
        subject.update!(body: 'Hello')
      end

      it 'creates a commentaire' do
        expect { subject.process_one(dossier) }.to change { dossier.commentaires.count }.by(1)
      end

      context 'with mark_as_pending_response' do
        before do
          subject.update!(mark_as_pending_response: 'true')
        end

        it 'marks the dossier as pending response' do
          expect { subject.process_one(dossier) }.to change { dossier.reload.pending_response? }.from(false).to(true)
        end

        it 'creates a pending response record linked to the commentaire' do
          subject.process_one(dossier)
          commentaire = dossier.commentaires.last
          expect(commentaire.dossier_pending_response).to be_present
          expect(commentaire.dossier_pending_response.pending?).to be true
        end
      end

      context 'without mark_as_pending_response' do
        it 'does not mark the dossier as pending response' do
          expect { subject.process_one(dossier) }.not_to change { dossier.reload.pending_response? }
        end
      end
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
