# frozen_string_literal: true

describe RevisionDescribableToLLMConcern do
  describe "#schema_to_llm" do
    context 'with header sections, a repetition and an annotation' do
      let(:procedure) do
        create(:procedure,
          public_type_de_champs: [
            { type: :header_section, level: 1, libelle: 'h1' },
            { type: :text, libelle: 'a' },
            { type: :repetition, libelle: 'r', children: [{ type: :text, libelle: 'r1' }, { type: :text, libelle: 'r2' }] },
            { type: :header_section, level: 2, libelle: 'h2' },
            { type: :text, libelle: 'b' },
          ],
          private_type_de_champs: [{ type: :text, libelle: 'c' }])
      end
      let(:revision) { procedure.draft_revision }

      def layout(schema) = schema.map { [it[:libelle], it[:position], it[:parent_id]] }

      it 'describes the form in document order, with positions among the champs outside any repetition or within it' do
        r = revision.public_root_type_de_champs.find { it.libelle == 'r' }

        expect(layout(revision.schema_to_llm)).to eq([
          ['h1', 0, nil], ['a', 1, nil], ['r', 2, nil], ['r1', 0, r.stable_id], ['r2', 1, r.stable_id], ['h2', 3, nil], ['b', 4, nil],
        ])
      end

      it 'tells a header section by its level' do
        schema = revision.schema_to_llm

        expect(schema.filter_map { it[:header_section_level] }).to eq([1, 2])
        expect(schema.first.keys).to eq([:stable_id, :type, :libelle, :mandatory, :description, :position, :header_section_level, :display_condition])
      end

      it 'leaves out the keys rejected' do
        expect(revision.schema_to_llm(reject: [:position, :parent_id]).flat_map(&:keys)).not_to include(:position, :parent_id)
      end

      it 'counts positions without a gap once a champ is removed' do
        revision.remove_type_de_champ(revision.public_root_type_de_champs.find { it.libelle == 'a' }.stable_id)

        expect(layout(revision.schema_to_llm).first(3).map { it.first(2) }).to eq([['h1', 0], ['r', 1], ['r1', 0]])
      end
    end

    context 'when a type_de_champ has nil options' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :date, libelle: "Date de naissance" }]) }
      let(:revision) { procedure.draft_revision }

      before do
        revision.public_root_type_de_champs.first.update_column(:options, nil)
      end

      it 'does not raise' do
        expect { revision.schema_to_llm }.not_to raise_error
      end
    end
  end
end
