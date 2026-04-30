# frozen_string_literal: true

describe Instructeurs::AvisController, type: :controller do
  context 'with a instructeur signed in' do
    render_views

    let(:now) { Time.zone.parse('01/02/2345') }
    let(:expert) { create(:expert) }
    let(:claimant) { create(:instructeur) }
    let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: procedure, notify_on_new_avis: false) }
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, :published, instructeurs: [instructeur]) }
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:avis_without_answer) { create(:avis, dossier: dossier, claimant: claimant, experts_procedure: experts_procedure) }

    before { sign_in(instructeur.user) }

    describe "#revoker" do
      let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: :attente_avis) }

      before do
        patch :revoquer, params: { procedure_id: procedure.id, id: avis_without_answer.id, statut: 'a-suivre' }
      end

      it "revoke the dossier" do
        expect(flash.notice).to eq("#{avis_without_answer.expert.email} ne peut plus donner son avis sur ce dossier.")
      end

      context "when attente_avis notifications exists" do
        it "destroys all attente_avis notifications" do
          expect(DossierNotification.exists?(notification.id)).to be_falsey
        end
      end
    end

    describe 'remind' do
      before do
        allow(AvisMailer).to receive(:avis_invitation_and_confirm_email).and_return(double(deliver_later: nil))
      end
      context 'without question' do
        let!(:avis) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure) }

        it 'sends a reminder to the expert' do
          patch :remind, params: { procedure_id: procedure.id, id: avis.id, statut: 'a-suivre' }
          expect(AvisMailer).to have_received(:avis_invitation_and_confirm_email)
          expect(flash.notice).to eq("Un mail de relance a été envoyé à #{avis.expert.email}")
          expect(avis.reload.reminded_at).to be_present
        end
      end

      context 'with question' do
        let!(:avis) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure, question_label: '123') }

        it 'sends a reminder to the expert' do
          patch :remind, params: { procedure_id: procedure.id, id: avis.id, statut: 'a-suivre' }
          expect(AvisMailer).to have_received(:avis_invitation_and_confirm_email)
          expect(flash.notice).to eq("Un mail de relance a été envoyé à #{avis.expert.email}")
          expect(avis.reload.reminded_at).to be_present
        end
      end

      context 'CSRF protection: GET no longer routes to remind' do
        let!(:avis) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure) }

        it 'GET /remind is not routable' do
          expect(get: remind_instructeur_avis_path(procedure, 'a-suivre', avis)).not_to be_routable
        end

        it 'PATCH /remind is routable' do
          expect(patch: remind_instructeur_avis_path(procedure, 'a-suivre', avis)).to be_routable
        end
      end
    end
  end
end
