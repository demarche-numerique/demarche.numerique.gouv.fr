# frozen_string_literal: true

describe DubiousProcedure, type: :model do
  describe '#all' do
    let!(:procedure) { create(:procedure, types_de_champ_public: tdcs) }
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

      context 'and a whitelisted procedure' do
        let(:procedure) { create(:procedure, :whitelisted) }

        it { expect(subject).to eq([]) }
      end

      context 'and a closed procedure' do
        let(:procedure) { create(:procedure, :closed) }

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
