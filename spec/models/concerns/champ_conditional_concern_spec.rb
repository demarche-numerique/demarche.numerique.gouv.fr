# frozen_string_literal: true

describe ChampConditionalConcern do
  include Logic

  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :decimal_number, stable_id: 99 }, { type: :decimal_number, stable_id: 999, condition: }]) }
  let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
  let(:champ) { dossier.root_public_champs.find { _1.stable_id == 99 }.tap { _1.update_column(:value, '1.1234') } }
  let(:last_champ) { dossier.root_public_champs.find { _1.stable_id == 999 }.tap { _1.update_column(:value, '1.1234') } }
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
