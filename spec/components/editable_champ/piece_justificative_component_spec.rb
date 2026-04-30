# frozen_string_literal: true

describe EditableChamp::PieceJustificativeComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

  let(:component) { described_class.new(form: nil, champ:) }

  describe '#max' do
    subject { component.max }

    context 'when champ is a piece_justificative with titre_identite nature' do
      let(:types_de_champ_public) { [{ type: :piece_justificative, nature: 'titre_identite' }] }

      it { is_expected.to eq(1) }
    end
  end
end
