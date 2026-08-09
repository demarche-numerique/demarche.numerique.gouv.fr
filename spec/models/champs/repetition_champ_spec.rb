# frozen_string_literal: true

describe Champs::RepetitionChamp do
  let(:procedure) {
    create(:procedure,
      types_de_champ_public: [
        {
          type: :repetition,
          children: [{ type: :text, libelle: "Ext" }], libelle: "Languages",
        },
      ])
  }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_champs_public.find(&:repetition?) }

  describe "#row_libelle" do
    context "with a single child (monochamp)" do
      it "returns the child's libelle" do
        expect(champ.row_libelle).to eq("Ext")
      end
    end

    context "with multiple children (multichamp)" do
      let(:procedure) {
        create(:procedure,
          types_de_champ_public: [
            {
              type: :repetition,
              children: [
                { type: :text, libelle: "Nom" },
                { type: :text, libelle: "Prénom" },
              ],
              libelle: "Personnes",
            },
          ])
      }

      it "returns the repetition block's libelle" do
        expect(champ.row_libelle).to eq("Personnes")
      end
    end
  end

  describe "#max_reached?" do
    let(:procedure) do
      create(:procedure,
        types_de_champ_public: [
          {
            type: :repetition,
            children: [{ type: :text }],
            libelle: "Bloc",
            limit_repetitions: '1',
            max_repetitions: '2',
          },
        ])
    end

    context "when limits are disabled" do
      before do
        tdc = dossier.revision.types_de_champ.find(&:repetition?)
        tdc.record.update!(limit_repetitions: '0')
      end

      it "returns false" do
        expect(champ.max_reached?).to be(false)
      end
    end

    context "after a cycle of disabling/enabling toggle without new max value" do
      before do
        tdc = dossier.revision.types_de_champ.find(&:repetition?)
        tdc.record.update!(limit_repetitions: '0')
        tdc.record.update!(limit_repetitions: '1')
      end

      it "returns false when no max value is configured" do
        expect(champ.max_reached?).to be(false)
      end
    end
  end

  describe "#validate_repetition_limits" do
    let(:procedure) do
      create(:procedure,
        types_de_champ_public: [
          {
            type: :repetition,
            children: [{ type: :text }],
            libelle: "Bloc",
            limit_repetitions: '1',
            min_repetitions: min_rep,
            max_repetitions: max_rep,
          },
        ])
    end
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.root_champs_public.find(&:repetition?) }

    context "when count is below min" do
      let(:min_rep) { 2 }
      let(:max_rep) { nil }

      before do
        champ_for_update(champ.rows.first.champs.first).update(value: "rb")
      end

      it "adds a repetition_too_few error" do
        champ.valid?(:champ_value)
        expect(champ.errors.where(:value, :repetition_too_few)).to be_present
      end
    end

    context "when count is 0 and min is set (no rows added)" do
      let(:min_rep) { 2 }
      let(:max_rep) { nil }

      before do
        champ.row_ids.each { |row_id| champ.remove_row(row_id, updated_by: "test") }
      end

      it "adds a repetition_too_few error even without any rows" do
        fresh_champ = dossier.reload.root_champs_public.find(&:repetition?)
        fresh_champ.valid?(:champ_value)
        expect(fresh_champ.errors.where(:value, :repetition_too_few)).to be_present
      end
    end

    context "when count exceeds max" do
      let(:min_rep) { nil }
      let(:max_rep) { 1 }

      before do
        champ_for_update(champ.rows.first.champs.first).update(value: "rb")
        champ.add_row(updated_by: "test")
        champ.add_row(updated_by: "test")
      end

      it "adds a repetition_too_many error" do
        champ.valid?(:champ_value)
        expect(champ.errors.where(:value, :repetition_too_many)).to be_present
      end
    end

    context "when count is within limits" do
      let(:min_rep) { 1 }
      let(:max_rep) { 3 }

      before do
        champ_for_update(champ.rows.first.champs.first).update(value: "rb")
      end

      it "does not add any errors" do
        champ.valid?(:champ_value)
        expect(champ.errors).to be_empty
      end
    end
  end

  describe "#for_tag" do
    before do
      champ_for_update(champ.rows.first.champs.first).update(value: "rb")
    end

    it "can render as string" do
      expect(champ.type_de_champ.champ_value_for_tag(champ).to_s).to eq(
        <<~TXT.strip
          Languages

          Ext : rb
        TXT
      )
    end

    it "as tiptap node" do
      expect(champ.type_de_champ.champ_value_for_tag(champ).to_tiptap_node).to include(type: 'orderedList')
    end
  end
end
