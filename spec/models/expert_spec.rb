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
      let(:procedure) { create(:procedure) }
      let(:old_experts_procedure) { create(:experts_procedure, expert: old_expert, procedure:) }
      let(:new_experts_procedure) { create(:experts_procedure, expert: new_expert, procedure:) }
      let!(:avis) { create(:avis, dossier: create(:dossier, procedure:), experts_procedure: old_experts_procedure) }

      before do
        new_experts_procedure
        subject
      end

      it 'transfers the avis to the new expert and removes the old experts_procedure' do
        expect(avis.reload.experts_procedure).to eq(new_experts_procedure)
        expect(ExpertsProcedure.exists?(old_experts_procedure.id)).to eq(false)
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
end
