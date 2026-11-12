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

      # A JSON array of ids ("[1,2]") — what a prefill URL or an API payload
      # carries — parses into Integers, not Strings.
      context 'when the ids are Integers' do
        let(:values) { [items.second.id, items.first.id] }

        it { is_expected.to be_empty }
      end

      context 'when the ids mix Integers and Strings' do
        let(:values) { [items.second.id, items.first.id.to_s] }

        it { is_expected.to be_empty }
      end

      context 'when a value is a label rather than an id' do
        let(:values) { ['fromage'] }

        it { is_expected.to eq([[:not_in_options, {}]]) }
      end

      context 'when a value only starts with the id of an item' do
        let(:values) { ["#{items.first.id}abc"] }

        it { is_expected.to eq([[:not_in_options, {}]]) }
      end

      # `options_for_select` skips the items whose first column is blank, so
      # the select never offers them: the rule must not accept them either.
      context 'when a value is the id of an item the select does not offer' do
        let!(:blank_item) { create(:referentiel_item, referentiel:, data: { row: { 'option' => '', 'calorie_kcal' => '1', 'poids_g' => '1' } }) }
        let(:values) { [blank_item.id.to_s] }

        it 'is not offered by the select' do
          expect(referentiel.options_for_select.map(&:last)).not_to include(blank_item.id.to_s)
        end

        it { is_expected.to eq([[:not_in_options, {}]]) }
      end

      context 'when the list has no referentiel yet' do
        let(:type_de_champ_attributes) { { type: :multiple_drop_down_list, drop_down_mode: 'advanced' } }
        let(:values) { ['1'] }

        it { is_expected.to eq([[:not_in_options, {}]]) }
      end
    end
  end

  describe '.allowed? query cost' do
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { type: :repetition, children: [{ type: :drop_down_list, drop_down_mode: 'advanced', referentiel: }] },
      ])
    end
    let(:dossier) { create(:dossier, procedure:) }
    let(:repetition_tdc) { procedure.active_revision.public_root_type_de_champs.first }
    let(:child_tdc) { procedure.active_revision.type_de_champ(repetition_tdc.stable_id).flat_children.first }

    def sql_touching(table, &block)
      queries = []
      callback = lambda { |*args| queries << args.last[:sql] if args.last[:sql].include?(table) }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &block)
      queries
    end

    # Every row of a repetition shares the same type de champ, hence the same
    # referentiel instance and its loaded items: the rule must read them, not
    # re-query the items of each champ.
    it 'reads the referentiel items once for the whole repetition' do
      item_id = referentiel.items.first.id.to_s
      Array.new(10) { dossier.repetition_add_row(repetition_tdc, updated_by: 'test') }
        .each { dossier.champ_for_update(child_tdc, row_id: it, updated_by: 'test').update!(value: item_id) }
      dossier.reload

      expect(sql_touching('referentiel_items') { dossier.validate(:champs_public_value) }.size).to eq(1)
    end
  end
end
