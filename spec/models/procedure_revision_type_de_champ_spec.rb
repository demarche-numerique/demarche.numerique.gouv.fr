# frozen_string_literal: true

describe ProcedureRevisionTypeDeChamp do
  describe '#upper_coordinates' do
    context 'when the coordinate is in a bloc bellow another coordinate' do
      let(:procedure) do
        create(:procedure,
               public_type_de_champs: [
                 { libelle: 'l1' },
                 {
                   type: :repetition, children: [
                     { libelle: 'l2.1' },
                     { libelle: 'l2.2' },
                   ],
                 },
               ])
      end

      let(:l2_2) do
        procedure
          .draft_revision
          .revision_type_de_champs.joins(:type_de_champ)
          .find_by(type_de_champ: { libelle: 'l2.2' })
      end

      it { expect(l2_2.upper_coordinates.map(&:libelle)).to match_array(["l1", "l2.1"]) }
    end

    context 'when the coordinate is an annotation' do
      let(:procedure) do
        create(:procedure,
               private_type_de_champs: [
                 { libelle: 'a1' },
                 { libelle: 'a2' },
               ],
               public_type_de_champs: [
                 { libelle: 'l1' },
                 {
                   type: :repetition, libelle: 'l2', children: [
                     { libelle: 'l2.1' },
                     { libelle: 'l2.2' },
                   ],
                 },
               ])
      end

      let(:a2) do
        procedure
          .draft_revision
          .revision_type_de_champs.joins(:type_de_champ)
          .find_by(type_de_champ: { libelle: 'a2' })
      end

      it { expect(a2.upper_coordinates.map(&:libelle)).to match_array(["l1", "l2", "a1"]) }
    end
  end

  describe '#preceding_siblings' do
    let(:revision) { procedure.draft_revision }
    let(:coordinate) { revision.revision_type_de_champs.joins(:type_de_champ).find_by(type_de_champ: { libelle: }) }

    context 'when the coordinate is an annotation' do
      let(:procedure) do
        create(:procedure,
               public_type_de_champs: [{ type: :header_section, libelle: 'p1', level: 1 }],
               private_type_de_champs: [
                 { type: :header_section, libelle: 'a1', level: 1 },
                 { type: :header_section, libelle: 'a2', level: 2 },
               ])
      end
      let(:libelle) { 'a2' }

      it { expect(coordinate.preceding_siblings.map(&:libelle)).to eq(['a1']) }
    end

    context 'when the coordinate is in a repetition' do
      let(:procedure) do
        create(:procedure,
               public_type_de_champs: [
                 { type: :header_section, libelle: 'l1', level: 1 },
                 {
                   type: :repetition, children: [
                     { type: :header_section, libelle: 'l2.1', level: 1 },
                     { type: :header_section, libelle: 'l2.2', level: 2 },
                   ],
                 },
               ])
      end
      let(:libelle) { 'l2.2' }

      it { expect(coordinate.preceding_siblings.map(&:libelle)).to eq(['l2.1']) }
    end
  end
end
