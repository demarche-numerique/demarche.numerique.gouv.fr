# frozen_string_literal: true

describe ChampConditionalConcern do
  include Logic

  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :decimal_number, stable_id: 99 }, { type: :decimal_number, stable_id: 999, condition: }]) }
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
  let(:champ) { dossier.public_root_champs.find { _1.stable_id == 99 }.tap { _1.update_column(:value, '1.1234') } }
  let(:last_champ) { dossier.public_root_champs.find { _1.stable_id == 999 }.tap { _1.update_column(:value, '1.1234') } }
  let(:condition) { nil }

  describe '#used_by_a_form_condition?' do
    context "when there are no condition" do
      it { expect(champ.used_by_a_form_condition?).to eq(false) }
    end

    context "when other tdc has a condition" do
      let(:condition) { ds_eq(champ_value(99), constant(1)) }

      it { expect(champ.used_by_a_form_condition?).to eq(true) }
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

    context 'inside a repetition' do
      let(:procedure) do
        create(:procedure, :published, public_type_de_champs: [
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

    context 'when the condition reads a checkbox nobody touched' do
      let(:unchecked) { ds_eq(Logic::ChampColumnValue.new(99, 'type_de_champ/99'), constant(false)) }
      let(:procedure) do
        create(:procedure, public_type_de_champs: [
          { type: :checkbox, stable_id: 99 },
          { type: :text, stable_id: 999, condition: unchecked },
        ])
      end
      let(:dossier) { create(:dossier, procedure:) }
      let(:conditional_champ) { dossier.public_root_champs.find { it.stable_id == 999 } }

      it 'reads « Non »' do
        expect(conditional_champ.visible?).to be true
      end
    end

    context 'when the condition reads a champ whose type changed since it was written' do
      let(:procedure) do
        create(:procedure, public_type_de_champs: [
          { type: :checkbox, stable_id: 99 },
          { type: :text, stable_id: 999, condition: ds_eq(champ_value(99), constant(true)) },
        ])
      end
      let(:dossier) { create(:dossier, procedure:) }
      let(:conditional_champ) { dossier.public_root_champs.find { it.stable_id == 999 } }

      before do
        dossier.champ_data.find { it.stable_id == 99 }.update_columns(type: 'Champs::YesNoChamp', value: 'true')
        dossier.reload
      end

      it 'reads the value the form displays' do
        expect(dossier.public_root_champs.first).to be_true
        expect(conditional_champ.visible?).to be true
      end
    end

    context 'when the condition no longer fits the type of the champ it reads' do
      let(:procedure) do
        create(:procedure, public_type_de_champs: [
          { type: :multiple_drop_down_list, stable_id: 99, options: ['val1', 'val2'] },
          { type: :text, stable_id: 999, condition: ds_include(champ_value(99), constant('val1')) },
        ])
      end
      let(:dossier) { create(:dossier, procedure:) }
      let(:conditional_champ) { dossier.public_root_champs.find { it.stable_id == 999 } }

      # the admin tests the draft procedure, then turns the champ the
      # condition reads into a yes/no: nothing rewrites the condition, and the
      # draft is only validated at publication
      before do
        draft = procedure.draft_revision
        draft.update_type_de_champ(draft.find_and_ensure_exclusive_use(99), type_champ: 'yes_no')
        dossier.champ_data.find { it.stable_id == 99 }.update_columns(value: 'true')
        dossier.reload
      end

      it 'is not met, so the champ is hidden' do
        expect(conditional_champ.visible?).to be false
      end
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
