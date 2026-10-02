# frozen_string_literal: true

describe Instructeurs::BatchOperationsController, type: :controller do
  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.individual }
  let(:dossier) { create(:dossier, :accepte, :with_individual, procedure: procedure) }

  describe '#POST create' do
    before { sign_in(instructeur.user) }

    let(:params) do
      {
        procedure_id: procedure.id,
        batch_operation: {
          operation: BatchOperation.operations.fetch(:archiver),
          dossier_ids: [dossier.id],
        },
        statut: 'a-suivre',
      }
    end

    subject { post :create, params: params }

    context 'ACL' do
      let(:params) do
        {
          procedure_id: create(:procedure).id,
          statut: 'a-suivre',
        }
      end

      it 'fails when procedure does not belongs to instructeur' do
        expect(subject).to have_http_status(302)
      end
    end

    context 'success with valid dossier_ids' do
      it 'creates a batch operation for our signed in instructeur' do
        expect { subject }.to change { instructeur.batch_operations.count }.by(1)
      end
      it 'created a batch operation contains dossiers, instructeur, groupe_instructeur' do
        subject
        batch_operation = BatchOperation.first
        expect(batch_operation.dossiers).to include(dossier)
        expect(batch_operation.instructeur).to eq(instructeur)
        expect(batch_operation.groupe_instructeurs.to_a).to eq(instructeur.groupe_instructeurs.where(procedure:).to_a)
      end
      it 'enqueues a BatchOperationJob' do
        expect { subject }.to have_enqueued_job(BatchOperationEnqueueAllJob).with(BatchOperation.last)
      end
    end

    context 'when archiving with dismiss_archive_warning' do
      let(:params) { super().merge(dismiss_archive_warning: '1') }

      it 'remembers that the instructeur dismissed the archive warning' do
        expect { subject }.to change { instructeur.reload.archive_warning_dismissed }.from(false).to(true)
      end
    end

    context 'when archiving without dismiss_archive_warning' do
      it 'keeps showing the archive warning' do
        expect { subject }.not_to change { instructeur.reload.archive_warning_dismissed }
      end
    end

    context 'when another operation is sent with dismiss_archive_warning' do
      let(:params) do
        super().deep_merge(batch_operation: { operation: BatchOperation.operations.fetch(:supprimer) }, dismiss_archive_warning: '1')
      end

      it 'does not touch the archive warning preference' do
        expect { subject }.not_to change { instructeur.reload.archive_warning_dismissed }
      end
    end

    context 'with an empty justificatif' do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
      let(:params) do
        {
          procedure_id: procedure.id,
          batch_operation: {
            operation: BatchOperation.operations.fetch(:accepter),
            dossier_ids: [dossier.id],
            justificatif_motivation: ActiveStorage::Blob.create_and_upload!(io: StringIO.new(''), filename: 'vide.pdf', content_type: 'application/pdf').signed_id,
          },
          statut: 'a-suivre',
        }
      end

      it 'does not create a batch operation and warns the instructeur' do
        expect { subject }.not_to change { instructeur.batch_operations.count }
        expect(flash.alert.first).to include('est vide (vide.pdf)')
      end
    end

    context 'fails with no dossiers' do
      let(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }

      it 'does not create a batch operation if no dossiers' do
        expect { subject }.not_to change { instructeur.batch_operations.count }
        expect(flash.alert).to eq("Le traitement de masse n’a pas été lancé. Vérifiez que l’action demandée est possible pour les dossiers sélectionnés")
      end
    end

    context 'when no dossier is selected' do
      let(:params) do
        {
          procedure_id: procedure.id,
          batch_operation: { operation: BatchOperation.operations.fetch(:archiver) },
          statut: 'a-suivre',
        }
      end

      it 'does not create a batch operation and warns the instructeur' do
        expect { subject }.not_to change { instructeur.batch_operations.count }
        expect(flash.alert).to eq("Le traitement de masse n’a pas été lancé. Vérifiez que l’action demandée est possible pour les dossiers sélectionnés")
      end
    end

    context 'when dossier_ids are sent as comma-joined strings' do
      let(:other_dossier) { create(:dossier, :accepte, :with_individual, procedure: procedure) }
      let(:params) do
        {
          procedure_id: procedure.id,
          batch_operation: {
            operation: BatchOperation.operations.fetch(:archiver),
            dossier_ids: ["#{dossier.id},#{other_dossier.id}", dossier.id.to_s],
          },
          statut: 'a-suivre',
        }
      end

      it 'splits and deduplicates them' do
        expect { subject }.to change { instructeur.batch_operations.count }.by(1)
        expect(BatchOperation.first.dossiers).to contain_exactly(dossier, other_dossier)
      end
    end
  end

  describe '#POST create_batch_commentaire' do
    before { sign_in(instructeur.user) }

    let(:params) do
      {
        procedure_id: procedure.id,
        batch_operation: {
          operation: BatchOperation.operations.fetch(:create_commentaire),
          dossier_ids: [dossier.id],
        },
        commentaire: {
          body: 'test',
          piece_jointe: nil,
        },
      }
    end

    subject { post :create_batch_commentaire, params: params }

    context 'success with valid dossier_ids' do
      it 'creates a batch operation for our signed in instructeur' do
        expect { subject }.to change { instructeur.batch_operations.count }.by(1)
      end

      it 'created a batch operation that contains dossiers, instructeur, groupe_instructeur' do
        subject
        batch_operation = BatchOperation.first
        expect(batch_operation.dossiers).to include(dossier)
        expect(batch_operation.instructeur).to eq(instructeur)
        expect(batch_operation.groupe_instructeurs.to_a).to eq(instructeur.groupe_instructeurs.where(procedure:).to_a)
      end

      it 'enqueues a BatchOperationJob' do
        expect { subject }.to have_enqueued_job(BatchOperationEnqueueAllJob).with(BatchOperation.last)
      end
    end

    context 'with mark_as_pending_response' do
      let(:params) do
        {
          procedure_id: procedure.id,
          batch_operation: {
            operation: BatchOperation.operations.fetch(:create_commentaire),
            dossier_ids: [dossier.id],
          },
          commentaire: {
            body: 'test',
            piece_jointe: nil,
          },
          mark_as_pending_response: 'true',
        }
      end

      it 'stores the mark_as_pending_response flag in the batch operation' do
        subject
        batch_operation = BatchOperation.first
        expect(batch_operation.mark_as_pending_response).to eq(true)
      end
    end
  end
end
