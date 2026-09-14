# frozen_string_literal: true

describe DropDownOptionsValidator do
  let(:procedure) { create(:procedure, public_type_de_champs: [type_de_champ_attributes]) }
  let(:type_de_champ) { procedure.active_revision.public_root_type_de_champs.first }

  describe '.violations' do
    subject(:violations) { described_class.violations(values, type_de_champ) }

    context 'with a simple list' do
      let(:type_de_champ_attributes) { { type: :drop_down_list, options: ['val1', 'val2'] } }

      context 'when every value is an option' do
        let(:values) { ['val2', 'val1'] }

        it { is_expected.to be_empty }
      end

      context 'when a value is not an option' do
        let(:values) { ['val1', 'other'] }

        it { is_expected.to eq([[:not_in_options, {}]]) }
      end

      context 'when the values are blank' do
        let(:values) { ['', nil] }

        it { is_expected.to be_empty }
      end
    end

    context "with a list accepting 'other'" do
      let(:type_de_champ_attributes) { { type: :drop_down_list, drop_down_other: true } }
      let(:values) { ['anything'] }

      it { is_expected.to be_empty }
    end

    context 'with an advanced list' do
      let(:referentiel) { create(:csv_referentiel, :with_items) }
      let(:type_de_champ_attributes) { { type: :multiple_drop_down_list, drop_down_mode: 'advanced', referentiel: } }
      let(:items) { referentiel.items }

      context 'when every value is the id of an item' do
        let(:values) { [items.second.id.to_s, items.first.id.to_s] }

        it { is_expected.to be_empty }
      end

      context 'when a value is the id of no item' do
        let(:values) { [items.first.id.to_s, (items.last.id + 1).to_s] }

        it { is_expected.to eq([[:not_in_options, {}]]) }
      end

      context 'when a value is a label rather than an id' do
        let(:values) { ['fromage'] }

        it { is_expected.to eq([[:not_in_options, {}]]) }
      end

      context 'when a value only starts with the id of an item' do
        let(:values) { ["#{items.first.id}abc"] }

        it { is_expected.to eq([[:not_in_options, {}]]) }
      end

      context 'when the list has no referentiel yet' do
        let(:type_de_champ_attributes) { { type: :multiple_drop_down_list, drop_down_mode: 'advanced' } }
        let(:values) { ['1'] }

        it { is_expected.to eq([[:not_in_options, {}]]) }
      end
    end
  end
end
