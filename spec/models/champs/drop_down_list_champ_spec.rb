# frozen_string_literal: true

describe Champs::DropDownListChamp do
  let(:types_de_champ_public) { [{ type: :drop_down_list, drop_down_other: other, referentiel:, drop_down_mode: }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:referentiel) { nil }
  let(:drop_down_mode) { nil }
  let(:champ) { dossier.root_champs_public.first.tap { _1.update(value:, other:) } }
  let(:value) { nil }
  let(:other) { nil }

  describe 'validations' do
    describe 'inclusion' do
      subject { champ.validate(:champ_value) }

      context 'when the other value is accepted' do
        let(:other) { true }

        context 'when the value is blank' do
          let(:value) { '' }

          it { is_expected.to be_truthy }
        end

        context 'when the value is included in the option list' do
          let(:value) { 'val1' }

          it { is_expected.to be_truthy }
        end

        context 'when the value is not included in the option list' do
          let(:value) { 'something else' }

          it { is_expected.to be_truthy }
        end
      end

      context 'when the other value is not accepted' do
        let(:other) { false }

        context 'when the value is blank' do
          let(:value) { '' }

          it { is_expected.to be_truthy }
        end

        context 'when the value is included in the option list' do
          let(:value) { 'val1' }

          it { is_expected.to be_truthy }
        end

        context 'when the value is not included in the option list' do
          let(:value) { 'something else' }

          it { is_expected.to be_falsey }
        end
      end
    end
  end

  describe '#drop_down_other?' do
    context 'when drop_down_other is nil' do
      it do
        champ.type_de_champ.record.drop_down_other = nil
        expect(champ.drop_down_other?).to be false

        champ.type_de_champ.record.drop_down_other = "0"
        expect(champ.drop_down_other?).to be false

        champ.type_de_champ.record.drop_down_other = false
        expect(champ.drop_down_other?).to be false

        champ.type_de_champ.record.drop_down_other = "1"
        expect(champ.drop_down_other?).to be true

        champ.type_de_champ.record.drop_down_other = true
        expect(champ.drop_down_other?).to be true
      end
    end
  end

  describe 'referentiel' do
    let(:drop_down_mode) { 'advanced' }
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:item) { referentiel.items.first }
    let(:value) { item.id.to_s }

    it '#referentiel_headers' do
      expect(champ.referentiel_headers).to eq([["option", "option"], ["calorie (kcal)", "calorie_kcal"], ["poids (g)", "poids_g"]])
    end

    it '#to_s' do
      expect(champ.value).to eq(value)
      expect(champ.to_s).to eq(item.value(champ.referentiel_headers.first.second))
    end

    it '#referentiel_item_column_values' do
      expect(champ.referentiel_item_column_values).to eq([["option", "fromage"], ["calorie (kcal)", "145"], ["poids (g)", "60"]])
    end

    context "when value is a value from simple mode" do
      let(:types_de_champ_public) { [{ type: :drop_down_list, drop_down_mode: "simple" }] }
      let(:value) { "fromage" }

      before do
        champ.save!
        champ.reload
      end

      it "clear old value without error" do
        expect(champ.value).to eq("fromage")

        champ.type_de_champ.record.update!(options: { "drop_down_mode": "advanced" }, referentiel:)
        champ.reload

        champ.save!
        expect(champ.value).to be_nil
      end
    end
  end
end
