# frozen_string_literal: true

RSpec.describe ExpertsProcedure, type: :model do
  describe '.granting_access' do
    subject { ExpertsProcedure.where(id: experts_procedures.default.id).granting_access }

    it { is_expected.to contain_exactly(experts_procedures.default) }

    context 'when the link has been revoked' do
      before { experts_procedures.default.update!(revoked_at: Time.zone.now) }

      context 'and the procedure manages its experts with a predefined list' do
        before { procedures.individual.update!(experts_require_administrateur_invitation: true) }

        it { is_expected.to be_empty }
      end

      context 'and the procedure lets instructeurs invite the experts they want' do
        it 'keeps the link: the revocation is dormant in that mode' do
          expect(subject).to contain_exactly(experts_procedures.default)
        end
      end

      context 'and the procedure has no value for that mode' do
        before { procedures.individual.update_column(:experts_require_administrateur_invitation, nil) }

        it { is_expected.to contain_exactly(experts_procedures.default) }
      end
    end

    context 'when the procedure has been deleted' do
      before { procedures.individual.update_column(:hidden_at, Time.zone.now) }

      it { is_expected.to be_empty }
    end
  end

  describe '#invited_expert_emails' do
    let(:procedure) { procedures.individual }
    let(:claimant) { instructeurs.default }
    let(:expert) { experts.default }
    let(:expert2) { create(:expert) }
    let(:expert3) { create(:expert) }
    let(:experts_procedure) { experts_procedures.default }
    let(:experts_procedure2) { create(:experts_procedure, expert: expert2, procedure: procedure) }
    let(:experts_procedure3) { create(:experts_procedure, expert: expert3, procedure: procedure) }
    subject { procedure.experts_procedures }

    context 'when there is one dossier' do
      let(:dossier) { dossiers.en_construction }

      context 'when a procedure has one avis and known instructeur' do
        let!(:avis) { create(:avis, dossier: dossier, claimant: claimant, experts_procedure: experts_procedure) }

        it do
          is_expected.to match_array([experts_procedure, experts_procedures.second])
          expect(procedure.experts.count).to eq(2)
          expect(procedure.experts).to match_array([expert, experts.second])
        end
      end

      context 'when a dossier has 2 avis from the same expert' do
        let!(:avis) { create(:avis, dossier: dossier, experts_procedure: experts_procedure) }
        let!(:avis2) { create(:avis, dossier: dossier, experts_procedure: experts_procedure) }

        it do
          is_expected.to match_array([experts_procedure, experts_procedures.second])
          expect(procedure.experts.count).to eq(2)
          expect(procedure.experts).to match_array([expert, experts.second])
        end
      end
    end

    context 'when there are two dossiers' do
      let(:dossier) { dossiers.en_construction }
      let(:dossier2) { dossiers.en_instruction }

      context 'and each one has an avis from 3 different experts' do
        let!(:avis) { create(:avis, dossier: dossier, experts_procedure: experts_procedure) }
        let!(:avis2) { create(:avis, dossier: dossier2, experts_procedure: experts_procedure2) }
        let!(:avis3) { create(:avis, dossier: dossier2, experts_procedure: experts_procedure3) }

        it do
          is_expected.to match_array([experts_procedure, experts_procedures.second, experts_procedure2, experts_procedure3])
          expect(procedure.experts.count).to eq(4)
          expect(procedure.experts).to match_array([expert, experts.second, expert2, expert3])
        end
      end
    end
  end
end
