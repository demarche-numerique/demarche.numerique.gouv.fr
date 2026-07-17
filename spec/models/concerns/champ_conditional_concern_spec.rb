# frozen_string_literal: true

describe ChampConditionalConcern do
  include Logic

  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :decimal_number, stable_id: 99 }, { type: :decimal_number, stable_id: 999, condition: }]) }
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
  let(:champ) { dossier.root_champs_public.find { _1.stable_id == 99 }.tap { _1.update_column(:value, '1.1234') } }
  let(:last_champ) { dossier.root_champs_public.find { _1.stable_id == 999 }.tap { _1.update_column(:value, '1.1234') } }
  let(:condition) { nil }

  describe '#dependent_conditions?' do
    context "when there are no condition" do
      it { expect(champ.dependent_conditions?).to eq(false) }
    end

    context "when other tdc has a condition" do
      let(:condition) { ds_eq(champ_value(99), constant(1)) }

      it { expect(champ.dependent_conditions?).to eq(true) }
    end
  end

  describe '#visible?' do
    context "when there are no condition" do
      it {
        expect(champ.visible?).to eq(true)
        expect(champ.valid?(:champ_value)).to eq(false)

        expect(last_champ.visible?).to eq(true)
        expect(last_champ.valid?(:champ_value)).to eq(false)
      }
    end

    context "when other tdc has a condition" do
      let(:condition) { ds_eq(champ_value(99), constant(1)) }

      it {
        expect(champ.visible?).to eq(true)
        expect(champ.valid?(:champ_value)).to eq(false)

        expect(last_champ.visible?).to eq(false)
        expect(last_champ.valid?(:champ_value)).to eq(true)
      }
    end

    context 'inside a conditional section' do
      let(:section_condition) { ds_eq(champ_value(1), constant(true)) }
      let(:procedure) do
        create(:procedure, types_de_champ_public: [
          { type: :yes_no, stable_id: 1 },
          { type: :header_section, level: 1, stable_id: 10, condition: section_condition },
          { type: :text, stable_id: 11 },
          { type: :header_section, level: 2, stable_id: 12 },
          { type: :checkbox, stable_id: 13 },
          { type: :repetition, stable_id: 14, children: [{ type: :text, stable_id: 15 }] },
          { type: :header_section, level: 1, stable_id: 20 },
          { type: :text, stable_id: 21, condition: ds_eq(champ_value(13), constant(true)) },
        ])
      end
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }

      def champ(stable_id)
        dossier.champ_data.find { it.stable_id == stable_id } || dossier.project_champ(dossier.find_type_de_champ_by_stable_id(stable_id))
      end

      before { champ(1).update_column(:value, yes_no_value) }

      context 'when the section is visible' do
        let(:yes_no_value) { 'true' }

        it 'every champ under the section is visible' do
          expect(champ(10).visible?).to be true
          expect(champ(11).visible?).to be true
          expect(champ(12).visible?).to be true
          expect(champ(13).visible?).to be true
          expect(champ(14).visible?).to be true
          expect(champ(15).visible?).to be true
          expect(champ(21).visible?).to be true
        end
      end

      context 'when the section is hidden' do
        let(:yes_no_value) { 'false' }

        it 'every champ under the section is hidden, including nested sections, repetitions and their rows' do
          expect(champ(10).visible?).to be false
          expect(champ(11).visible?).to be false
          expect(champ(12).visible?).to be false
          expect(champ(13).visible?).to be false
          expect(champ(14).visible?).to be false
          expect(champ(15).visible?).to be false
        end

        it 'a condition targeting a champ inside the hidden section computes as hidden' do
          expect(champ(21).visible?).to be false
        end

        it 'the champ outside the section stays visible' do
          expect(champ(20).visible?).to be true
        end
      end

      context 'when the section condition targets a champ inside the section itself' do
        let(:procedure) do
          create(:procedure, types_de_champ_public: [
            { type: :header_section, level: 1, stable_id: 10, condition: section_condition },
            { type: :yes_no, stable_id: 1 },
          ])
        end
        let(:yes_no_value) { 'false' }

        it 'does not loop' do
          expect(champ(10).visible?).to be false
          expect(champ(1).visible?).to be false
        end
      end

      context 'when the procedure uses the legacy behaviour' do
        let(:procedure) do
          create(:procedure, section_conditions_hide_champs: false, types_de_champ_public: [
            { type: :yes_no, stable_id: 1 },
            { type: :header_section, level: 1, stable_id: 10, condition: section_condition },
            { type: :text, stable_id: 11 },
          ])
        end
        let(:yes_no_value) { 'false' }

        it 'only the section itself is hidden' do
          expect(champ(10).visible?).to be false
          expect(champ(11).visible?).to be true
        end
      end
    end

    context 'inside a repetition' do
      let(:procedure) do
        create(:procedure, :published, types_de_champ_public: [
          {
            type: :repetition,
            children: [{ type: :yes_no }],
            condition:,
          },
        ])
      end

      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:first_repet) { dossier.champ_data.find { it.type == "Champs::RepetitionChamp" } }
      let(:first_yes_no) { dossier.champ_data.find { it.type == "Champs::YesNoChamp" && it.row_id == first_repet.row_id } }

      context 'when the repetition is visible' do
        let(:condition) { nil }

        it 'the enclosed champ is hidden' do
          expect(first_repet.visible?).to be true
          expect(first_yes_no.visible?).to be true
        end
      end

      context 'when the repetition is hidden' do
        let(:condition) { ds_eq(constant(true), constant(false)) }

        it 'the enclosed champ is hidden' do
          expect(first_repet.visible?).to be false
          expect(first_yes_no.visible?).to be false
        end
      end
    end
  end

  describe '#conditional_visibility?' do
    let(:procedure) do
      create(:procedure, section_conditions_hide_champs:, types_de_champ_public: [
        { type: :yes_no, stable_id: 1 },
        { type: :header_section, level: 1, stable_id: 10, condition: ds_eq(champ_value(1), constant(true)) },
        { type: :text, stable_id: 11 },
      ])
    end
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:text_champ) { dossier.champ_data.find { it.stable_id == 11 } }

    context 'when section conditions hide champs' do
      let(:section_conditions_hide_champs) { true }

      it { expect(text_champ.conditional_visibility?).to be true }
    end

    context 'with the legacy behaviour' do
      let(:section_conditions_hide_champs) { false }

      it { expect(text_champ.conditional_visibility?).to be false }
    end
  end

  describe '#submitted_filled?' do
    context 'when dossier on submitted revision' do
      it { expect(champ.submitted_filled?).to be_falsey }
    end

    context 'when dossier not on submitted revision' do
      before {
        procedure.publish_revision!(procedure.administrateurs.first)
        dossier.rebase!
        dossier.reload
      }

      it { expect(champ.submitted_filled?).to be_truthy }

      context 'when champ is empty' do
        before { champ.update(value: nil) }
        it { expect(champ.submitted_filled?).to be_falsey }
      end
    end
  end
end
