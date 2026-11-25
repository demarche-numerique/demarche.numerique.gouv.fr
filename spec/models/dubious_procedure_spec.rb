# frozen_string_literal: true

describe DubiousProcedure, type: :model do
  describe '#all' do
    let!(:procedure) { create(:procedure, public_type_de_champs: tdcs) }
    let(:allowed_tdc) { { libelle: 'fournir' } }
    subject { DubiousProcedure.all }

    context 'with suspicious champs' do
      let(:forbidden_tdcs) do
        [
          { libelle: 'num de securite sociale, stp' },
          { libelle: "t’aurais une carte bancaire ?" },
        ]
      end

      let(:tdcs) { forbidden_tdcs + [allowed_tdc] }

      it 'returns dubious procedures' do
        expect(subject.first.id).to eq(procedure.id)
        expect(subject.first.libelle).to eq(procedure.libelle)
        expect(subject.first.dubious_champs).to include("num de securite sociale, stp")
        expect(subject.first.dubious_champs).to include("t’aurais une carte bancaire ?")
      end

      it 'leaves out a champ no revision lays out any more' do
        draft = procedure.draft_revision
        draft.remove_type_de_champ(draft.type_de_champs.find { it.libelle == 'num de securite sociale, stp' }.stable_id)

        expect(subject.find { it.id == procedure.id }.dubious_champs).to eq("t’aurais une carte bancaire ?")
      end

      it 'names once a champ several revisions lay out' do
        procedure.publish!(procedure.administrateurs.first)
        draft = procedure.reload.draft_revision
        draft.update_type_de_champ(draft.type_de_champs.first.stable_id, description: 'edited')

        expect(subject.find { it.id == procedure.id }.dubious_champs).to eq("num de securite sociale, stp - t’aurais une carte bancaire ?")
      end

      context 'and a whitelisted procedure' do
        let(:procedure) { create(:procedure, :whitelisted) }

        it { expect(subject).to eq([]) }
      end

      context 'and a closed procedure' do
        let(:procedure) { procedures.close }

        it { expect(subject).to eq([]) }
      end

      context 'and a discarded procedure' do
        let(:procedure) { create(:procedure, :discarded) }

        it { expect(subject).to eq([]) }
      end
    end

    context 'with no suspicious champs' do
      let(:tdcs) { [allowed_tdc] }

      it { expect(subject).to eq([]) }
    end
  end
end
