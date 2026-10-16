# frozen_string_literal: true

RSpec.describe Avis, type: :model do
  describe '#email_to_display' do
    context 'when expert is known' do
      it { expect(avis.pending.email_to_display).to eq(experts.default.email) }
    end
  end

  describe '#submit_answer' do
    it 'saves the answer' do
      expect(avis.pending.submit_answer(answer: 'Avis favorable.')).to be(true)
      expect(avis.pending.reload.answer).to eq('Avis favorable.')
    end

    it 'refuses a blank answer' do
      pending_avis = avis.pending

      expect(pending_avis.submit_answer(answer: ' ')).to be(false)
      expect(pending_avis.errors).to be_of_kind(:answer, :blank)
      expect(pending_avis.reload.answer).to be_nil
    end
  end

  describe '.by_latest' do
    context 'with 3 avis on the same dossier' do
      let!(:avis2) { create(:avis, dossier: dossiers.en_instruction, experts_procedure: experts_procedures.default, updated_at: 4.hours.ago) }
      let!(:avis3) { create(:avis, dossier: dossiers.en_instruction, experts_procedure: experts_procedures.default, updated_at: 3.hours.ago) }

      subject { Avis.where(dossier: dossiers.en_instruction, experts_procedure: experts_procedures.default).by_latest }

      it { is_expected.to eq([avis.pending, avis3, avis2]) }
    end
  end

  describe "an avis is linked to an experts_procedure" do
    it { expect(avis.pending.experts_procedure).to eq(experts_procedures.default) }
  end

  describe ".not_revoked" do
    subject { Avis.where(id: avis.pending.id).not_revoked }

    it { is_expected.to contain_exactly(avis.pending) }

    context "when the procedure manages its experts with a predefined list" do
      before { procedures.individual.update!(experts_require_administrateur_invitation: true) }

      it { is_expected.to contain_exactly(avis.pending) }
    end

    context "when the avis itself is revoked" do
      before { avis.pending.update_column(:revoked_at, Time.zone.now) }

      it { is_expected.to be_empty }
    end

    context "when the procedure has been deleted" do
      before { procedures.individual.update_column(:hidden_at, Time.zone.now) }

      it { is_expected.to be_empty }
    end

    context "when the expert is revoked from the procedure" do
      before { experts_procedures.default.update!(revoked_at: Time.zone.now) }

      context "and the procedure lets instructeurs invite the experts they want" do
        it "keeps the avis accessible: the revocation has no meaning in that mode" do
          expect(subject).to contain_exactly(avis.pending)
        end
      end

      context "and the procedure manages its experts with a predefined list" do
        before { procedures.individual.update!(experts_require_administrateur_invitation: true) }

        it { is_expected.to be_empty }
      end

      context "and the procedure has no value for that mode" do
        before { procedures.individual.update_column(:experts_require_administrateur_invitation, nil) }

        it { is_expected.to contain_exactly(avis.pending) }
      end
    end
  end

  describe ".revoke_by!" do
    context "when no answer" do
      it "supprime l’avis" do
        pending_avis = avis.pending
        expect { pending_avis.revoke_by!(instructeurs.default) }.to change { Avis.exists?(pending_avis.id) }.from(true).to(false)
        expect(pending_avis).to be_destroyed
      end
    end

    context "with answer" do
      it "revoque l’avis" do
        answered_avis = avis.answered
        answered_avis.revoke_by!(instructeurs.default)
        expect(answered_avis).not_to be_destroyed
        expect(answered_avis).to be_revoked
      end
    end

    context "by an instructeur who can't revoke" do
      let(:other_instructeur) { create(:instructeur) }

      it "doesn't revoke avis and returns false" do
        answered_avis = avis.answered
        expect(answered_avis.revoke_by!(other_instructeur)).to be_falsey
        expect(answered_avis).not_to be_destroyed
        expect(answered_avis).not_to be_revoked
      end
    end
  end

  describe "revokable_by?" do
    let(:instructeur) { instructeurs.default }
    let(:claimant_expert) { create(:instructeur) }
    let(:another_expert) { create(:expert) }
    let(:dossier) { dossiers.en_instruction }

    context "when avis claimed by an expert" do
      let(:claimed_avis) { create(:avis, dossier:, claimant: claimant_expert, experts_procedure: experts_procedures.default) }

      it "is revokable by this expert or any instructeurs of the dossier" do
        expect(claimed_avis.revokable_by?(claimant_expert)).to be_truthy
        expect(claimed_avis.revokable_by?(another_expert)).to be_falsy
        expect(claimed_avis.revokable_by?(instructeur)).to be_truthy
      end
    end

    context "when avis claimed by an instructeur" do
      let(:another_instructeur) { create(:instructeur) }
      let(:claimed_avis) { create(:avis, dossier:, claimant: instructeur, experts_procedure: experts_procedures.default) }

      before { another_instructeur.assign_to_procedure(procedures.individual) }

      it "is revokable by any instructeur of the dossier, not by an expert" do
        expect(claimed_avis.revokable_by?(instructeur)).to be_truthy
        expect(claimed_avis.revokable_by?(another_expert)).to be_falsy
        expect(claimed_avis.revokable_by?(another_instructeur)).to be_truthy
      end
    end
  end

  describe "question_label cleanup" do
    it "nullify empty" do
      created_avis = create(:avis, question_label: " ", dossier: dossiers.en_construction, experts_procedure: experts_procedures.default, claimant: instructeurs.default)
      expect(created_avis.question_label).to be_nil
    end

    it "strip" do
      created_avis = create(:avis, question_label: "my question ", dossier: dossiers.en_construction, experts_procedure: experts_procedures.default, claimant: instructeurs.default)
      expect(created_avis.question_label).to eq("my question")
    end
  end

  describe 'normalization' do
    it 'removes non-printable characters from answer (ASCII control character "End of Transmission Block), seen in pdf' do
      built_avis = build(:avis, answer: "Valid\x17Answer", dossier: dossiers.en_construction, experts_procedure: experts_procedures.default)
      built_avis.validate
      expect(built_avis.answer).to eq("ValidAnswer")
    end

    it 'collapses a blank answer to nil' do
      built_avis = build(:avis, answer: " \n ", dossier: dossiers.en_construction, experts_procedure: experts_procedures.default)
      built_avis.validate
      expect(built_avis.answer).to be_nil
    end
  end

  describe 'answer presence' do
    let(:unanswered_avis) { avis.pending }

    it 'refuses a blank answer on update' do
      expect(unanswered_avis.update(answer: ' ')).to be(false)
      expect(unanswered_avis.errors.of_kind?(:answer, :blank)).to be(true)
    end

    it 'accepts an answer on update' do
      expect(unanswered_avis.update(answer: 'Avis favorable')).to be(true)
    end
  end
end
