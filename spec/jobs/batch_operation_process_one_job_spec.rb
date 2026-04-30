# frozen_string_literal: true

describe BatchOperationProcessOneJob, type: :job do
  describe 'perform' do
    let(:batch_operation) do
      create(:batch_operation, :archiver,
                               options.merge(instructeur: create(:instructeur)))
    end
    let(:dossier_job) { batch_operation.dossiers.first }
    subject { BatchOperationProcessOneJob.new(batch_operation, dossier_job) }
    let(:options) { {} }

    it 'when it works' do
      allow_any_instance_of(BatchOperation).to receive(:process_one).with(dossier_job).and_return(true)
      expect { subject.perform_now }
        .to change { batch_operation.dossier_operations.success.pluck(:dossier_id) }
        .from([])
        .to([dossier_job.id])
    end

    it 'when it fails for an "unknown" reason' do
      allow_any_instance_of(BatchOperation).to receive(:process_one).with(dossier_job).and_raise("boom")
      expect { subject.perform_now }.to raise_error('boom')

      expect(batch_operation.dossier_operations.error.pluck(:dossier_id)).to eq([dossier_job.id])
    end

    it 'calls finalize_if_complete! even when process_one raises' do
      allow_any_instance_of(BatchOperation).to receive(:process_one).with(dossier_job).and_raise("boom")
      expect_any_instance_of(BatchOperation).to receive(:finalize_if_complete!)

      expect { subject.perform_now }.to raise_error("boom")
    end

    context 'when operation is "archiver"' do
      it 'archives the dossier in the batch' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.archived? }
          .from(false)
          .to(true)
      end
    end

    context 'when operation is "desarchiver"' do
      let(:batch_operation) do
        create(:batch_operation, :desarchiver,
                                 options.merge(instructeur: create(:instructeur)))
      end
      it 'archives the dossier in the batch' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.archived? }
          .from(true)
          .to(false)
      end
    end

    context 'when operation is "passer_en_instruction"' do
      let(:batch_operation) do
        create(:batch_operation, :passer_en_instruction,
                                 options.merge(instructeur: create(:instructeur)))
      end

      it 'changes the dossier to en_instruction in the batch' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.en_instruction? }
          .from(false)
          .to(true)
      end
    end

    context 'when operation is "repousser_expiration"' do
      let(:batch_operation) do
        create(:batch_operation, :repousser_expiration,
                                 options.merge(instructeur: create(:instructeur)))
      end
      it 'extends conservation of the dossier in the batch' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.conservation_extension }
          .from(dossier_job.conservation_extension)
          .to(dossier_job.conservation_extension + 1.month)
      end
    end

    context 'when operation is "demander un avis externe"' do
      let(:batch_operation) do
        create(:batch_operation, :create_avis,
                                 options.merge(instructeur: create(:instructeur),
                                              emails: ['expert@exemple.fr'],
                                              introduction: 'Test avis'))
      end

      it 'add avis to the dossier' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.avis.count }
          .from(0)
          .to(1)
      end
    end

    context 'when operation is "envoyer un message aux usagers"' do
      let(:batch_operation) do
        create(:batch_operation, :create_commentaire,
                                 options.merge(instructeur: create(:instructeur), body: 'Test message'))
      end

      it 'add a commentaire to the dossier' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.commentaires.count }
          .from(0)
          .to(1)
      end
    end

    context 'when operation is "follow"' do
      let(:batch_operation) do
        create(:batch_operation, :follow,
                                 options.merge(instructeur: create(:instructeur)))
      end

      it 'adds a follower to the dossier' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.follows.count }
          .from(0)
          .to(1)
      end
    end

    context 'when operation is "unfollow"' do
      let(:batch_operation) do
        create(:batch_operation, :unfollow,
                                 options.merge(instructeur: create(:instructeur)))
      end

      it 'removes a follower to the dossier' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.follows.count }
          .from(1)
          .to(0)
      end
    end

    context 'when operation is "repasser en construction"' do
      let(:batch_operation) do
        create(:batch_operation, :repasser_en_construction,
                                 options.merge(instructeur: create(:instructeur)))
      end

      it 'changed the dossier to en construction' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.en_construction? }
          .from(false)
          .to(true)
      end
    end

    context 'when operation is "accepter"' do
      let(:batch_operation) do
        create(:batch_operation, :accepter,
                                 options.merge(instructeur: create(:instructeur), motivation: 'motivation'))
      end

      it 'accepts the dossier in the batch' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.accepte? }
          .from(false)
          .to(true)
      end

      it 'accepts the dossier in the batch with a motivation' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.motivation }
          .from(nil)
          .to('motivation')
      end

      context 'when it raises a  ActiveRecord::StaleObjectError' do
        before { allow_any_instance_of(Dossier).to receive(:after_accepter).and_raise(ActiveRecord::StaleObjectError) }

        it 'with invalid dossier (ex: ActiveRecord::StaleObjectError), unlink dossier/batch_operation with update_column' do
          scope = double
          expect(scope).to receive(:find).with(dossier_job.id).and_return(dossier_job)
          expect_any_instance_of(BatchOperation).to receive(:dossiers_safe_scope).and_return(scope)
          dossier_job.errors.add('KC')

          expect do
            begin
              subject.perform_now
            rescue ActiveRecord::StaleObjectError
              # noop, juste want to catch existing error but not others
            end
          end.to change { dossier_job.reload.batch_operation }.from(batch_operation).to(nil)
        end

        it 'does not change dossier state' do
          expect do
            begin
              subject.perform_now
            rescue ActiveRecord::StaleObjectError
              # noop, juste want to catch existing error but not others
            end
          end.not_to change { dossier_job.reload.accepte? }
        end
      end
    end

    context 'when operation is "accepter" with justificatif' do
      let(:fake_justificatif) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new("ma justification"), filename: 'piece_justificative_0.pdf', content_type: 'application/pdf') }

      let(:batch_operation) do
        create(:batch_operation, :accepter,
               options.merge(instructeur: create(:instructeur), motivation: 'motivation', justificatif_motivation: fake_justificatif.signed_id))
      end

      it 'accepts the dossier in the batch with a justificatif' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.justificatif_motivation.filename }
          .from(nil)
          .to(fake_justificatif.filename)
      end
    end

    context 'when operation is "refuser"' do
      let(:batch_operation) do
        create(:batch_operation, :refuser,
                                 options.merge(instructeur: create(:instructeur), motivation: 'motivation'))
      end

      it 'refuses the dossier in the batch' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.refuse? }
          .from(false)
          .to(true)
      end

      it 'refuses the dossier in the batch with a motivation' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.motivation }
          .from(nil)
          .to('motivation')
      end
    end

    context 'when operation is "restaurer"' do
      let(:batch_operation) do
        create(:batch_operation, :restaurer,
                                 options.merge(instructeur: create(:instructeur)))
      end

      it 'restores the dossier' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.hidden_by_administration? }
          .from(true)
          .to(false)
      end
    end

    context 'when operation is "restaurer_repousser_expiration"' do
      let(:batch_operation) do
        create(:batch_operation, :restaurer_repousser_expiration,
                                 options.merge(instructeur: create(:instructeur)))
      end

      context "when the dossier is en_construction and expired" do
        it 'restores and extends conservation' do
          subject.perform_now
          dossier_job.reload

          expect(dossier_job.hidden_by_expired?).to eq(false)
          expect(dossier_job.conservation_extension).to eq(1.month)
          expect(dossier_job.hidden_by_reason).to eq(nil)
        end
      end

      context "when the dossier is termine, was deleted by administration and then expired" do
        let(:dossier_job) { batch_operation.dossiers.second }

        it 'restores and extends conservation' do
          subject.perform_now
          dossier_job.reload

          expect(dossier_job.hidden_by_expired?).to eq(false)
          expect(dossier_job.hidden_by_administration?).to eq(false)
          expect(dossier_job.conservation_extension).to eq(1.month)
          expect(dossier_job.hidden_by_reason).to eq(nil)
        end
      end
    end

    context 'when operation is "classer_sans_suite"' do
      let(:batch_operation) do
        create(:batch_operation, :classer_sans_suite,
                                 options.merge(instructeur: create(:instructeur), motivation: 'motivation'))
      end

      it 'closes without continuation the dossier in the batch' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.sans_suite? }
          .from(false)
          .to(true)
      end

      it 'closes without continuation the dossier in the batch with a motivation' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.motivation }
          .from(nil)
          .to('motivation')
      end
    end

    context 'when operation is "supprimer"' do
      let(:batch_operation) do
        create(:batch_operation, :supprimer,
                                 options.merge(instructeur: create(:instructeur)))
      end

      it 'changed the dossier to en construction' do
        expect { subject.perform_now }
          .to change { dossier_job.reload.hidden_by_administration? }
          .from(false)
          .to(true)
      end
    end

    context 'when the dossier is out of sync (ie: someone applied a transition somewhere we do not know)' do
      let(:instructeur) { create(:instructeur) }
      let(:procedure) { create(:simple_procedure, instructeurs: [instructeur]) }
      let(:dossier) { create(:dossier, :accepte, :with_individual, archived: true, procedure: procedure) }
      let(:batch_operation) { create(:batch_operation, operation: :archiver, instructeur: instructeur, dossiers: [dossier]) }

      it 'does run process_one' do
        allow(batch_operation).to receive(:process_one).and_raise("should have been prevented")
        subject.perform_now
      end

      it 'when it fails from dossiers_safe_scope.find' do
        scope = double
        expect(scope).to receive(:find).with(dossier_job.id).and_raise(ActiveRecord::RecordNotFound)
        expect_any_instance_of(BatchOperation).to receive(:dossiers_safe_scope).and_return(scope)

        subject.perform_now

        expect(batch_operation.reload.failed_dossier_ids).to eq([])
        expect(batch_operation.dossiers).not_to include(dossier_job)
      end
    end
  end
end
