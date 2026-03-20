# frozen_string_literal: true

describe Instructeurs::CommentairesController, type: :controller do
  let(:expert) { create(:expert) }
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, :for_individual, instructeurs: [instructeur]) }
  let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: procedure) }

  render_views

  context 'as instructeur' do
    before { sign_in(instructeur.user) }

    describe 'destroy' do
      context 'when it works' do
        let(:commentaire) { create(:commentaire, instructeur: instructeur, dossier: dossier) }
        subject { delete :destroy, params: { dossier_id: dossier.id, procedure_id: procedure.id, id: commentaire.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'respond with OK and flash' do
          expect(subject).to have_http_status(:ok)
          expect(subject.body).to include('Message supprimé')
          expect(subject.body).to include('alert-success')
          expect(subject.body).to include('Votre message a été supprimé')
          expect(commentaire.reload).to be_discarded
          expect(commentaire.body).to be_empty
        end

        context 'when instructeur is not owner' do
          let(:commentaire) { create(:commentaire, dossier: dossier) }

          it 'does not delete the message' do
            expect(subject.body).to include('alert-danger')
            expect(commentaire.reload).not_to be_discarded
            expect(commentaire.body).not_to be_empty
          end
        end

        context 'when a pending correction is attached' do
          let!(:correction) { create(:dossier_correction, commentaire:, dossier:) }

          it 'does not allow deleting the message' do
            expect(subject).to have_http_status(:ok)
            expect(subject.body).to include('alert-danger')
            expect(commentaire.reload).not_to be_discarded
            expect(correction.reload).to be_pending
          end
        end

        context 'when a cancelled correction is attached' do
          let!(:correction) { create(:dossier_correction, commentaire:, dossier:, cancelled_at: Time.current, resolved_at: Time.current) }

          it 'allows deleting the message' do
            expect(subject).to have_http_status(:ok)
            expect(subject.body).to include('Message supprimé')
            expect(commentaire.reload).to be_discarded
          end
        end

        context 'when a message has an attachment' do
          let(:commentaire) { create(:commentaire, instructeur: instructeur, dossier: dossier) }
          let(:rib_path) { 'spec/fixtures/files/RIB.pdf' }

          before do
            commentaire.piece_jointe.attach(
              io: File.open(rib_path),
              filename: 'RIB.pdf',
              content_type: 'application/pdf',
              metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
            )
          end

          it 'removes the attachment when the message is deleted' do
            expect(subject).to have_http_status(:ok)

            commentaire.reload
            expect(commentaire).to be_discarded
            expect(commentaire.body).to be_empty
            expect(subject.body).not_to include('RIB.pdf')
          end
        end
      end

      context 'when commentaire has already been discarded' do
        let(:commentaire) { create(:commentaire, instructeur: instructeur, dossier: dossier, discarded_at: 2.hours.ago) }
        subject { delete :destroy, params: { dossier_id: dossier.id, procedure_id: procedure.id, id: commentaire.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'does not allow deleting again' do
          expect(subject).to have_http_status(:ok)
          expect(subject.body).to include('alert-danger')
        end
      end
    end

    describe 'cancel_correction' do
      let(:commentaire) { create(:commentaire, instructeur: instructeur, dossier: dossier) }
      subject { post :cancel_correction, params: { dossier_id: dossier.id, procedure_id: procedure.id, id: commentaire.id, statut: 'a-suivre' }, format: :turbo_stream }

      context 'when a pending correction is attached' do
        let!(:correction) { create(:dossier_correction, commentaire:, dossier:) }

        it 'cancels the correction and keeps the message' do
          expect(subject).to have_http_status(:ok)
          expect(subject.body).to include('alert-success')
          expect(subject.body).to include('La demande de correction a été annulée')
          expect(correction.reload).to be_cancelled
          expect(correction).to be_resolved
          expect(commentaire.reload).not_to be_discarded
          expect(commentaire.body).not_to be_empty
        end
      end

      context 'when no pending correction' do
        it 'returns an error' do
          expect(subject).to have_http_status(:ok)
          expect(subject.body).to include('alert-danger')
          expect(subject.body).to include('Aucune demande de correction en attente')
        end
      end

      context 'when instructeur is not owner' do
        let(:other_instructeur) { create(:instructeur) }
        let(:commentaire) { create(:commentaire, instructeur: other_instructeur, dossier: dossier) }
        let!(:correction) { create(:dossier_correction, commentaire:, dossier:) }

        it 'does not cancel the correction' do
          expect(subject.body).to include('alert-danger')
          expect(correction.reload).not_to be_cancelled
        end
      end
    end

    describe 'IDOR protection' do
      let(:other_procedure) { create(:procedure, :published, :for_individual) }
      let(:other_dossier) { create(:dossier, :en_construction, :with_individual, procedure: other_procedure) }
      let(:other_commentaire) { create(:commentaire, dossier: other_dossier) }

      context 'destroy on a dossier the instructeur has no access to' do
        subject { delete :destroy, params: { dossier_id: other_dossier.id, procedure_id: other_procedure.id, id: other_commentaire.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'raises ActiveRecord::RecordNotFound' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'cancel_correction on a dossier the instructeur has no access to' do
        let!(:correction) { create(:dossier_correction, commentaire: other_commentaire, dossier: other_dossier) }
        subject { post :cancel_correction, params: { dossier_id: other_dossier.id, procedure_id: other_procedure.id, id: other_commentaire.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'raises ActiveRecord::RecordNotFound' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end

  context 'as expert' do
    before { sign_in(expert.user) }

    describe 'destroy' do
      context 'when it works' do
        let(:commentaire) { create(:commentaire, expert: expert, dossier: dossier) }
        subject { delete :destroy, params: { dossier_id: dossier.id, procedure_id: procedure.id, id: commentaire.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'respond with OK and flash' do
          expect(subject).to have_http_status(:ok)
          expect(subject.body).to include('Message supprimé')
          expect(subject.body).to include('alert-success')
          expect(subject.body).to include('Votre message a été supprimé')
        end
      end
    end
  end
end
