# frozen_string_literal: true

RSpec.describe Expert, type: :model do
  describe 'an expert could be add to a procedure' do
    let(:procedure) { create(:procedure) }
    let(:expert) { create(:expert) }

    before do
      procedure.experts << expert
      procedure.reload
    end

    it do
      expect(procedure.experts).to eq([expert])
      expect(ExpertsProcedure.where(expert: expert, procedure: procedure).count).to eq(1)
      expect(ExpertsProcedure.where(expert: expert, procedure: procedure).first.allow_decision_access).to be_falsy
    end
  end

  describe '#merge' do
    let(:old_expert) { create(:expert) }
    let(:new_expert) { create(:expert) }

    subject { new_expert.merge(old_expert) }

    context 'when the old expert does not exist' do
      let(:old_expert) { nil }

      it { expect { subject }.not_to raise_error }
    end

    context 'when an old expert access a procedure' do
      let(:procedure) { create(:procedure) }

      before do
        procedure.experts << old_expert
        subject
      end

      it 'transfers the access to the new expert' do
        expect(procedure.reload.experts).to match_array(new_expert)
      end
    end

    context 'when an old expert access a hidden procedure' do
      let(:procedure) { create(:procedure, hidden_at: 1.month.ago) }

      before do
        procedure.experts << old_expert
        subject
      end

      it 'transfers the access to the new expert' do
        expect(procedure.reload.experts).to match_array(new_expert)
      end
    end

    context 'when both expert access a procedure' do
      let(:procedure) { create(:procedure) }

      before do
        procedure.experts << old_expert
        procedure.experts << new_expert
        subject
      end

      it 'removes the old one' do
        expect(procedure.reload.experts). to match_array(new_expert)
      end
    end

    context 'when both experts access a procedure and the old expert has an avis to give' do
      let(:old_expert) { experts.default }
      let(:new_expert) { experts.second }
      let!(:old_experts_procedure) { experts_procedures.default }
      let!(:new_experts_procedure) { experts_procedures.second }
      let!(:pending_avis) { avis.pending }

      before { subject }

      it 'transfers the avis to the new expert and removes the old experts_procedure' do
        expect(pending_avis.reload.experts_procedure).to eq(new_experts_procedure)
        expect(ExpertsProcedure.exists?(old_experts_procedure.id)).to eq(false)
      end
    end

    context 'when the old expert has an active access and the new expert a revoked one' do
      let(:procedure) { procedures.individual }
      let!(:old_experts_procedure) { create(:experts_procedure, expert: old_expert, procedure:) }
      let!(:new_experts_procedure) { create(:experts_procedure, expert: new_expert, procedure:, revoked_at: 1.day.ago) }

      before { subject }

      it 'reactivates the surviving experts_procedure' do
        expect(new_experts_procedure.reload.revoked_at).to eq(nil)
      end
    end

    context 'when an old expert has a commentaire' do
      let(:dossier) { create(:dossier) }
      let(:commentaire) { CommentaireService.create(old_expert, dossier, body: "Mon commentaire") }

      before do
        commentaire
        subject
      end

      it 'transfers the commentaire to the new expert' do
        expect(new_expert.reload.commentaires).to match_array(commentaire)
      end
    end

    context 'when an old expert claims for an avis' do
      let!(:avis) { create(:avis, dossier: create(:dossier), claimant: old_expert) }

      before do
        subject
      end

      it 'transfers the claim to the new expert' do
        avis_claimed_by_new_expert = Avis
          .where(claimant_id: new_expert.id, claimant_type: Expert.name)

        expect(avis_claimed_by_new_expert).to match_array(avis)
      end
    end
  end

  describe '.autocomplete_mails' do
    subject { Expert.autocomplete_mails(procedure) }

    let(:procedure) { create(:procedure, experts_require_administrateur_invitation: true) }
    let(:expert) { create(:expert) }
    let(:revoked_expert) { create(:expert) }
    let(:unsigned_expert) { create(:expert) }
    let(:new_unsigned_expert) { create(:expert) }

    before do
      procedure.experts << expert << revoked_expert << unsigned_expert << new_unsigned_expert
      ExpertsProcedure.find_by(expert: revoked_expert, procedure: procedure)
        .update!(revoked_at: 1.day.ago)
      unsigned_expert.user.update!(last_sign_in_at: nil, created_at: 2.days.ago)
      new_unsigned_expert.user.update!(last_sign_in_at: nil)
    end

    context 'when procedure experts need administrateur invitation' do
      it 'returns only not revoked experts' do
        expect(subject).to eq([
          expert,
          unsigned_expert,
          new_unsigned_expert,
        ]
          .map { _1.user.email }
          .sort)
      end
    end

    context 'when procedure experts can be anyone' do
      let(:procedure) { create(:procedure, experts_require_administrateur_invitation: false) }

      it 'prefill autocomplete with all confirmed experts in the procedure' do
        expect(subject).to eq([expert.user.email, revoked_expert.user.email, new_unsigned_expert.user.email].sort)
      end
    end
  end

  describe '#avis_summary' do
    subject { experts.default.avis_summary[:unanswered] }

    it { is_expected.to eq(1) }

    context 'when the dossier is hidden by the administration' do
      before { avis.pending.dossier.update!(hidden_by_administration_at: Time.zone.now) }

      it { is_expected.to eq(0) }
    end

    context 'when the dossier is termine' do
      before { avis.pending.dossier.update_column(:state, Dossier.states.fetch(:accepte)) }

      it { is_expected.to eq(0) }
    end

    context 'when the expert is revoked from a procedure that manages its experts with a predefined list' do
      before do
        procedures.individual.update!(experts_require_administrateur_invitation: true)
        experts_procedures.default.update!(revoked_at: Time.zone.now)
      end

      it { is_expected.to eq(0) }
    end
  end

  describe '#dossiers_from_not_revoked_avis' do
    let(:expert) { create(:expert) }
    let(:claimant) { create(:expert) }
    let(:procedure) { create(:procedure, :published) }
    let(:experts_procedure) { create(:experts_procedure, expert:, procedure:) }
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    let!(:avis) { create(:avis, dossier:, claimant:, experts_procedure:) }

    subject { expert.dossiers_from_not_revoked_avis }

    it { is_expected.to contain_exactly(dossier) }

    context 'when the avis itself is revoked' do
      # update_column: revoking bypasses the on: :update answer-presence validation
      before { avis.update_column(:revoked_at, Time.zone.now) }

      it { is_expected.to be_empty }
    end

    context 'when the expert is revoked from the procedure' do
      before { experts_procedure.update!(revoked_at: Time.zone.now) }

      context 'and the procedure manages its experts with a predefined list' do
        before { procedure.update!(experts_require_administrateur_invitation: true) }

        it { is_expected.to be_empty }
      end

      context 'and the procedure lets instructeurs invite the experts they want' do
        it { is_expected.to contain_exactly(dossier) }
      end
    end
  end

  describe '#can_be_deleted?' do
    let(:expert) { create(:expert) }

    subject { expert.can_be_deleted? }

    context 'without any procedure nor avis' do
      it { is_expected.to be true }
    end

    context 'when attached to a kept procedure' do
      before { create(:experts_procedure, expert:, procedure: procedures.individual) }

      it { is_expected.to be false }
    end

    context 'when only attached to a discarded procedure' do
      let(:procedure) { create(:procedure) }

      before do
        create(:experts_procedure, expert:, procedure:)
        procedure.discard!
      end

      it { is_expected.to be true }
    end

    context 'when its link to a kept procedure was revoked' do
      before { create(:experts_procedure, expert:, procedure: procedures.individual, revoked_at: Time.zone.now) }

      it { is_expected.to be true }
    end

    context 'when it still has avis' do
      it { expect(experts.default.can_be_deleted?).to be false }
    end

    # The avis requested from another expert would otherwise lose its claimant.
    context 'when it requested an avis from another expert' do
      before { create(:avis, claimant: expert) }

      it { is_expected.to be false }
    end

    # Its messages would otherwise read as sent by the usager.
    context 'when it sent a message' do
      before { create(:commentaire, expert:, email: expert.email) }

      it { is_expected.to be false }
    end
  end
end
