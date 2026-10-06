# frozen_string_literal: true

describe Champs::RepetitionChamp do
  let(:procedure) {
    create(:procedure,
      public_type_de_champs: [
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
          public_type_de_champs: [
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
        public_type_de_champs: [
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
        tdc = dossier.revision.type_de_champs.find(&:repetition?)
        tdc.update!(limit_repetitions: '0')
      end

      it "returns false" do
        expect(champ.max_reached?).to be(false)
      end
    end

    context "after a cycle of disabling/enabling toggle without new max value" do
      before do
        tdc = dossier.revision.type_de_champs.find(&:repetition?)
        tdc.update!(limit_repetitions: '0')
        tdc.update!(limit_repetitions: '1')
      end

      it "returns false when no max value is configured" do
        expect(champ.max_reached?).to be(false)
      end
    end
  end

  describe "#validate_repetition_limits" do
    let(:procedure) do
      create(:procedure,
        public_type_de_champs: [
          {
            type: :repetition,
            children:,
            libelle: "Bloc",
            limit_repetitions: '1',
            min_repetitions: min_rep,
            max_repetitions: max_rep,
          },
        ])
    end
    let(:children) { [{ type: :text }] }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.root_champs_public.find(&:repetition?) }

    context "when count is below min" do
      let(:min_rep) { 2 }
      let(:max_rep) { nil }

      before do
        champ_for_update(champ.rows.first.flat_children.first).update(value: "rb")
      end

      it "does not add a repetition_too_few error while the dossier is being filled" do
        champ.valid?(:champ_value)
        expect(champ.errors.where(:value, :repetition_too_few)).to be_empty
      end

      it "adds a repetition_too_few error on submission" do
        champ.valid?([:champ_value, :champ_completeness])
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
        fresh_champ.valid?([:champ_value, :champ_completeness])
        expect(fresh_champ.errors.where(:value, :repetition_too_few)).to be_present
      end
    end

    context "when an added row is left empty" do
      let(:min_rep) { 2 }
      let(:max_rep) { nil }

      before do
        champ_for_update(champ.rows.first.flat_children.first).update(value: "rb")
        champ.add_row(updated_by: "test")
      end

      it "does not count the empty row" do
        champ.valid?([:champ_value, :champ_completeness])
        expect(champ.errors.where(:value, :repetition_too_few)).to be_present
        expect(champ.min_repetitions_reached?).to be(false)
      end
    end

    context "when a row misses a mandatory value" do
      let(:children) { [{ type: :text, libelle: "Nom" }, { type: :text, libelle: "Rôle", mandatory: true }] }
      let(:min_rep) { 2 }
      let(:max_rep) { nil }

      before do
        champ_for_update(champ.rows.first.flat_children.first).update(value: "Ada")
        champ_for_update(champ.rows.first.flat_children.last).update(value: "Dev")
        champ.add_row(updated_by: "test")
        champ_for_update(champ.rows.last.flat_children.first).update(value: "Grace")
      end

      it "does not count the incomplete row" do
        champ.valid?([:champ_value, :champ_completeness])
        expect(champ.errors.where(:value, :repetition_too_few)).to be_present
      end

      it "counts the row once its mandatory values are filled" do
        champ_for_update(champ.rows.last.flat_children.last).update(value: "Ops")

        champ.valid?([:champ_value, :champ_completeness])
        expect(champ.errors.where(:value, :repetition_too_few)).to be_empty
        expect(champ.min_repetitions_reached?).to be(true)
      end
    end

    context "when count exceeds max" do
      let(:min_rep) { nil }
      let(:max_rep) { 1 }

      before do
        champ_for_update(champ.rows.first.flat_children.first).update(value: "rb")
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
        champ_for_update(champ.rows.first.flat_children.first).update(value: "rb")
      end

      it "does not add any errors" do
        champ.valid?([:champ_value, :champ_completeness])
        expect(champ.errors).to be_empty
      end
    end
  end

  describe "#for_tag" do
    before do
      champ_for_update(champ.rows.first.flat_children.first).update(value: "rb")
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
