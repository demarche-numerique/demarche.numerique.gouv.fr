# frozen_string_literal: true

describe EditableChamp::PieceJustificativeComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.project_champs_public.first }

  let(:component) { described_class.new(form: nil, champ:) }

  describe '#max' do
    subject { component.max }

    context 'when champ is a piece_justificative with titre_identite nature' do
      let(:types_de_champ_public) { [{ type: :piece_justificative, nature: 'titre_identite' }] }

      it { is_expected.to eq(1) }
    end

    ['rib', 'justificatif_domicile', 'avis_impot'].each do |ocr_nature|
      context "when champ is a piece_justificative with #{ocr_nature} nature" do
        let(:types_de_champ_public) { [{ type: :piece_justificative, nature: ocr_nature }] }

        it { is_expected.to eq(1) }
      end
    end
  end
end
