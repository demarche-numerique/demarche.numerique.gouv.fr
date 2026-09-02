# frozen_string_literal: true

describe Logic do
  include Logic

  it 'serializes deserializes' do
    expect(Logic.from_h(constant(1).to_h)).to eq(constant(1))
    expect(Logic.from_json(constant(1).to_json)).to eq(constant(1))

    expect(Logic.from_h(empty.to_h)).to eq(empty)

    expect(Logic.from_h(champ_value(1).to_h)).to eq(champ_value(1))

    expect(Logic.from_h(greater_than(constant(1), constant(2)).to_h)).to eq(greater_than(constant(1), constant(2)))

    expect(Logic.from_h(ds_and([constant(true), constant(true), constant(false)]).to_h))
      .to eq(ds_and([constant(true), constant(true), constant(false)]))
  end

  describe '.errors' do
    let(:number) { build(:type_de_champ_integer_number, stable_id: 1) }
    let(:too_big) { greater_than(champ_value(1), constant(3)) }
    let(:too_small) { less_than(champ_value(1), constant(2)) }

    it 'reports the structural errors first' do
      expect(Logic.errors(ds_and([too_big, ds_eq(champ_value(1), constant('a')), too_small]), [number]).map { it[:type] }).to eq([:incompatible])
    end

    it 'then the contradictions, on the root only' do
      expect(Logic.errors(ds_or([too_big, too_small]), [number])).to be_empty
      expect(Logic.errors(ds_or([ds_and([too_big, too_small]), too_big]), [number])).to be_empty
      expect(Logic.errors(ds_and([too_big, too_small]), [number])).to eq([{ type: :contradiction, stable_id: 1, atoms: [too_big, too_small] }])
    end

    it 'checks a single atom as well' do
      expect(Logic.errors(too_big, [number])).to be_empty
      expect(Logic.errors(ds_eq(champ_value(1), constant(2.5)), [number])).to eq([{ type: :contradiction, stable_id: 1, atoms: [ds_eq(champ_value(1), constant(2.5))] }])
    end
  end

  describe '.ensure_compatibility_from_left' do
    let(:type_de_champs) { [] }
    subject { Logic.ensure_compatibility_from_left(condition, type_de_champs) }

    context 'when it s fine' do
      let(:condition) { greater_than(constant(1), constant(1)) }

      it { is_expected.to eq(condition) }
    end

    context 'when empty equal true' do
      let(:condition) { ds_eq(empty, constant(true)) }

      it { is_expected.to eq(empty_operator(empty, empty)) }
    end

    context 'when true greater_than 1' do
      let(:condition) { greater_than(constant(true), constant(0)) }

      it { is_expected.to eq(ds_eq(constant(true), constant(true))) }
    end

    context 'when number empty operator true' do
      let(:condition) { empty_operator(constant(1), constant(true)) }

      it { is_expected.to eq(ds_eq(constant(1), constant(0))) }
    end

    context 'when dropdown empty operator true' do
      let(:drop_down) { create(:type_de_champ_drop_down_list) }
      let(:type_de_champs) { [drop_down] }
      let(:first_option) { drop_down.drop_down_options.first }
      let(:condition) { empty_operator(champ_value(drop_down.stable_id), constant(true)) }

      it { is_expected.to eq(ds_eq(champ_value(drop_down.stable_id), constant(first_option))) }
    end

    context 'when multiple dropdown empty operator true' do
      let(:multiple_drop_down) { create(:type_de_champ_multiple_drop_down_list) }
      let(:type_de_champs) { [multiple_drop_down] }
      let(:first_option) { multiple_drop_down.drop_down_options.first }
      let(:condition) { empty_operator(champ_value(multiple_drop_down.stable_id), constant(true)) }

      it { is_expected.to eq(ds_include(champ_value(multiple_drop_down.stable_id), constant(first_option))) }
    end

    context 'when dropdown has no options' do
      let(:drop_down) { create(:type_de_champ_drop_down_list) }
      let(:type_de_champs) { [drop_down] }
      let(:condition) { empty_operator(champ_value(drop_down.stable_id), empty) }

      it 'returns a stable condition and reports the missing value' do
        drop_down.update!(drop_down_options: [])

        expect(subject.errors(type_de_champs)).to include(
          a_hash_including(type: :empty_options, stable_id: drop_down.stable_id)
        )
      end
    end
  end

  describe '.compatible_type?' do
    it do
      expect(Logic.compatible_type?(constant(true), constant(true), [])).to be true
      expect(Logic.compatible_type?(constant(1), constant(true), [])).to be false
    end

    context 'with a dropdown' do
      let(:drop_down) { create(:type_de_champ_drop_down_list) }
      let(:first_option) { drop_down.drop_down_options.first }

      it do
        expect(Logic.compatible_type?(champ_value(drop_down.stable_id), constant('a'), [drop_down])).to be true
      end
    end
  end

  describe 'priority' do
    # (false && true) || true = true
    it { expect(ds_or([ds_and([constant(false), constant(true)]), constant(true)]).compute).to be true }

    # false && (true || true) = false
    it { expect(ds_and([constant(false), ds_or([constant(true), constant(true)])]).compute).to be false }
  end

  describe '.add_empty_condition_to' do
    it do
      expect(Logic.add_empty_condition_to(nil)).to eq(empty_operator(empty, empty))
      expect(Logic.add_empty_condition_to(constant(true))).to eq(ds_and([constant(true), empty_operator(empty, empty)]))
      expect(Logic.add_empty_condition_to(ds_or([constant(true)]))).to eq(ds_or([constant(true), empty_operator(empty, empty)]))
    end
  end
end
