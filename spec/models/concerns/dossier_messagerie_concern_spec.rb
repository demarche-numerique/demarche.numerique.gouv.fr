# frozen_string_literal: true

RSpec.describe DossierMessagerieConcern do
  describe '#unread_message_for_user?' do
    let(:dossier) { create(:dossier, :en_construction) }

    subject { dossier.unread_message_for_user? }

    context 'when an instructeur sent an unread message' do
      before { create(:commentaire, dossier:, instructeur: create(:instructeur), seen_by_recipient_at: nil) }

      it { is_expected.to be_truthy }
    end

    context 'when an expert sent an unread message' do
      before { create(:commentaire, dossier:, expert: create(:expert), seen_by_recipient_at: nil) }

      it { is_expected.to be_truthy }
    end

    context 'when the dossier is en_instruction' do
      let(:dossier) { create(:dossier, :en_instruction) }

      before { create(:commentaire, dossier:, instructeur: create(:instructeur), seen_by_recipient_at: nil) }

      it { is_expected.to be_truthy }
    end

    context 'when the agent message has been seen' do
      before { create(:commentaire, dossier:, instructeur: create(:instructeur), seen_by_recipient_at: 1.day.ago) }

      it { is_expected.to be_falsey }
    end

    context 'when the agent message is discarded' do
      before { create(:commentaire, dossier:, instructeur: create(:instructeur), seen_by_recipient_at: nil, discarded_at: Time.current) }

      it { is_expected.to be_falsey }
    end

    context 'when the message was sent by the usager' do
      before { create(:commentaire, dossier:, seen_by_recipient_at: nil) }

      it { is_expected.to be_falsey }
    end

    context 'when the dossier has no message' do
      it { is_expected.to be_falsey }
    end

    context 'when the dossier is pending_correction' do
      before do
        create(:commentaire, dossier:, instructeur: create(:instructeur), seen_by_recipient_at: nil)
        create(:dossier_correction, dossier:)
      end

      it { is_expected.to be_falsey }
    end

    context 'when the dossier is pending_response' do
      before do
        create(:commentaire, dossier:, instructeur: create(:instructeur), seen_by_recipient_at: nil)
        create(:dossier_pending_response, dossier:)
      end

      it { is_expected.to be_falsey }
    end

    context 'when the association is preloaded' do
      before { create(:commentaire, dossier:, instructeur: create(:instructeur), seen_by_recipient_at: nil) }

      it 'reads the loaded association' do
        preloaded = Dossier
          .where(id: dossier.id)
          .includes(:unread_commentaires_for_user, :pending_corrections, :awaiting_responses)
          .first

        expect(preloaded.unread_commentaires_for_user).to be_loaded
        expect(preloaded.unread_message_for_user?).to be_truthy
      end
    end
  end
end
