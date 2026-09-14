# frozen_string_literal: true

describe Champs::MultipleDropDownListChamp do
  let(:public_type_de_champs) { [{ type: :multiple_drop_down_list, options: ["val1", "val2", "val3", "[brackets] val4"] }] }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_champs_public.first.tap { _1.update(value:) } }
  let(:value) { nil }

  describe 'validations' do
    subject { champ.validate(:champ_value) }

    describe 'inclusion' do
      context 'when the value is nil' do
        it { is_expected.to be_truthy }
      end

      context 'when the value is an empty string' do
        let(:value) { '' }

        it { is_expected.to be_truthy }
      end

      context 'when the value is an empty array' do
        let(:value) { [] }

        it { is_expected.to be_truthy }
      end

      context 'when the value is included in the option list' do
        let(:value) { ["val3", "val1"] }

        it { is_expected.to be_truthy }
      end

      context 'when the value is not included in the option list' do
        let(:value) { ["totoro", "val1"] }

        it { is_expected.to be_falsey }
      end

      context 'set value' do
        it {
          champ.value = ["val1"]
          expect(champ.value).to eq("[\"val1\"]")
          champ.value = 'val2'
          expect(champ.value).to eq("[\"val1\",\"val2\"]")
          champ.value = "[brackets] val4"
          expect(champ.value).to eq("[\"val1\",\"val2\",\"[brackets] val4\"]")
          champ.value = nil
          expect(champ.value).to be_nil
          champ.value = ["val1"]
          expect(champ.value).to eq("[\"val1\"]")
          champ.value = []
          expect(champ.value).to be_nil
          champ.value = ["val1"]
          expect(champ.value).to eq("[\"val1\"]")
          champ.value = ''
          expect(champ.value).to be_nil
        }
      end
    end
  end

  describe "validations of an advanced list" do
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:public_type_de_champs) { [{ type: :multiple_drop_down_list, drop_down_mode: "advanced", referentiel: }] }
    let(:item) { referentiel.items.first }
    let(:champ) { dossier.root_champs_public.first }

    it "accepts the ids of items before the champ is saved" do
      champ.value = [item.id.to_s]
      champ.validate(:champ_value)
      expect(champ.errors).to be_empty
    end

    it "rejects a saved selection whose item was deleted since" do
      champ.update!(value: [item.id.to_s])
      item.destroy!
      champ.validate(:champ_value)
      expect(champ.errors).to be_of_kind(:value, :not_in_options)
    end
  end

  describe "#for_tag" do
    let(:value) { ["val1", "val2"] }
    it { expect(champ.type_de_champ.champ_value_for_tag(champ).to_s).to eq("val1, val2") }
  end

  describe "#focusable_input_id" do
    context "when drop_down_options is empty" do
      before { champ.type_de_champ.update_column(:options, {}) }

      it "does not raise" do
        expect(champ.drop_down_options).to be_empty
        expect { champ.focusable_input_id }.not_to raise_error
      end
    end
  end
end
