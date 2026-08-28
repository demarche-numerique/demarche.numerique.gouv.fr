# frozen_string_literal: true

describe Logic::Branches do
  include Logic

  let(:yes_no) { build(:type_de_champ_yes_no, stable_id: 1, mandatory: true) }
  let(:number) { build(:type_de_champ_integer_number, stable_id: 2, mandatory: false) }
  let(:if_yes) { build(:type_de_champ_text, stable_id: 3, condition: ds_eq(champ_value(1), constant(true))) }
  let(:if_no) { build(:type_de_champ_text, stable_id: 4, condition: ds_eq(champ_value(1), constant(false))) }
  let(:if_adult) { build(:type_de_champ_text, stable_id: 5, condition: greater_than_eq(champ_value(2), constant(18))) }
  let(:plain) { build(:type_de_champ_text, stable_id: 6) }

  subject(:clusters) { described_class.new(type_de_champs).clusters }

  def visible_sets(cluster) = cluster.branches.map { it.visible.to_a.sort }

  def sources(cluster) = cluster.sources.map(&:type_de_champ)

  context 'without conditions' do
    let(:type_de_champs) { [yes_no, plain] }

    it { is_expected.to be_empty }
  end

  context 'with a mandatory yes/no source' do
    let(:type_de_champs) { [yes_no, if_yes, if_no, plain] }

    it 'has a branch per answer' do
      expect(clusters.size).to eq(1)
      expect(sources(clusters.first)).to eq([yes_no])
      expect(clusters.first.members).to eq([if_yes, if_no])
      expect(clusters.first.branches.map { [it.regions[champ_value(1)].values.to_a, it.visible.to_a] }).to contain_exactly([[true], [3]], [[false], [4]])
    end
  end

  context 'with an optional source' do
    let(:type_de_champs) { [number, if_adult] }

    it 'has a blank branch where nothing is displayed' do
      # < 18, 18, > 18, blank
      expect(visible_sets(clusters.first)).to contain_exactly([], [5], [5], [])
      expect(clusters.first.branches.map { it.regions[champ_value(2)] }).to include(Logic::Domain::Blank)
      expect(clusters.first.branches).to all(satisfy { |branch| adult?(branch.regions[champ_value(2)]) == branch.visible.include?(5) })
    end

    def adult?(region) = region != Logic::Domain::Blank && !region.restrict(Logic::GreaterThanEq, 18).empty?
  end

  context 'with members targeting each other' do
    let(:first) { build(:type_de_champ_yes_no, stable_id: 3, mandatory: true, condition: ds_eq(champ_value(4), constant(true))) }
    let(:second) { build(:type_de_champ_yes_no, stable_id: 4, mandatory: true, condition: ds_eq(champ_value(3), constant(true))) }
    let(:type_de_champs) { [first, second] }

    it 'keeps the form order and displays neither' do
      expect(clusters.first.members).to eq([first, second])
      expect(visible_sets(clusters.first)).to all(be_empty)
    end
  end

  context 'with a champ compared to another champ' do
    let(:other) { build(:type_de_champ_integer_number, stable_id: 12, mandatory: true) }
    let(:same) { build(:type_de_champ_text, stable_id: 13, condition: ds_eq(champ_value(2), champ_value(12))) }
    let(:type_de_champs) { [number, other, same] }

    it 'cannot decide it and never displays the dependent' do
      expect(visible_sets(clusters.first)).to all(be_empty)
    end
  end

  context 'with independent sources' do
    let(:type_de_champs) { [yes_no, number, if_yes, if_adult] }

    it 'splits them into clusters' do
      expect(clusters.map { sources(it) }).to eq([[yes_no], [number]])
      expect(clusters.map { it.branches.size }).to eq([2, 4])
    end
  end

  context 'with a champ targeting two sources' do
    let(:both) { build(:type_de_champ_text, stable_id: 7, condition: ds_and([ds_eq(champ_value(1), constant(true)), greater_than_eq(champ_value(2), constant(18))])) }
    let(:type_de_champs) { [yes_no, number, if_yes, if_adult, both] }

    it 'joins the clusters' do
      expect(clusters.size).to eq(1)
      expect(sources(clusters.first)).to eq([yes_no, number])
      expect(clusters.first.branches.size).to eq(8)
      expect(visible_sets(clusters.first)).to contain_exactly([3], [3, 5, 7], [3, 5, 7], [3], [], [5], [5], [])
    end
  end

  context 'with a conditional source' do
    let(:if_yes) { build(:type_de_champ_yes_no, stable_id: 3, mandatory: true, condition: ds_eq(champ_value(1), constant(true))) }
    let(:nested) { build(:type_de_champ_text, stable_id: 8, condition: ds_eq(champ_value(3), constant(true))) }
    let(:either) { build(:type_de_champ_text, stable_id: 9, condition: ds_or([ds_eq(champ_value(3), constant(false)), ds_eq(champ_value(1), constant(false))])) }
    let(:type_de_champs) { [yes_no, if_yes, nested, either] }

    it 'hides what depends on a hidden source, atom by atom' do
      cluster = clusters.first

      expect(sources(cluster)).to eq([yes_no, if_yes])
      expect(cluster.members).to eq([if_yes, nested, either])
      # yes_no × if_yes: (true, true) (true, false) (false, true) (false, false)
      expect(visible_sets(cluster)).to contain_exactly([3, 8], [3, 9], [9], [9])
    end
  end

  context 'with a conditional source moved below its dependent' do
    let(:if_yes) { build(:type_de_champ_yes_no, stable_id: 3, mandatory: true, condition: ds_eq(champ_value(1), constant(true))) }
    let(:nested) { build(:type_de_champ_text, stable_id: 8, condition: ds_eq(champ_value(3), constant(true))) }
    let(:type_de_champs) { [yes_no, nested, if_yes] }

    it 'decides the source first' do
      expect(clusters.first.members).to eq([if_yes, nested])
      expect(visible_sets(clusters.first)).to contain_exactly([3, 8], [3], [], [])
    end
  end

  context 'with a source no condition can reason about' do
    let(:text) { build(:type_de_champ_text, stable_id: 10) }
    let(:dependent) { build(:type_de_champ_text, stable_id: 11, condition: ds_eq(champ_value(10), constant('a'))) }
    let(:type_de_champs) { [text, dependent] }

    it 'never displays the dependent' do
      expect(visible_sets(clusters.first)).to eq([[]])
    end
  end

  context 'with a source gone from the form' do
    let(:type_de_champs) { [if_yes, plain] }

    it 'never displays the dependent' do
      expect(clusters.first.sources).to be_empty
      expect(visible_sets(clusters.first)).to eq([[]])
    end
  end

  context 'with as many branches as the cap can hold' do
    let(:type_de_champs) do
      sources = (1..13).map { build(:type_de_champ_yes_no, stable_id: it, mandatory: true) }
      dependent = build(:type_de_champ_text, stable_id: 100, condition: ds_and(sources.map { ds_eq(champ_value(it.stable_id), constant(true)) }))

      sources + [dependent]
    end

    it 'enumerates the cluster' do
      expect(clusters.first.branches.size).to eq(2**13)
    end
  end

  context 'with more branches than the cap' do
    let(:type_de_champs) do
      sources = (1..14).map { build(:type_de_champ_yes_no, stable_id: it, mandatory: true) }
      dependent = build(:type_de_champ_text, stable_id: 100, condition: ds_and(sources.map { ds_eq(champ_value(it.stable_id), constant(true)) }))

      sources + [dependent]
    end

    it 'leaves the cluster unenumerated' do
      expect(clusters.first).to be_capped
    end
  end

  context 'with a multiple choice mentioning more options than the cap can hold' do
    let(:options) { (1..30).map { "option #{it}" } }
    let(:choices) { build(:type_de_champ_multiple_drop_down_list, stable_id: 14, mandatory: true, drop_down_options: options) }
    let(:type_de_champs) do
      [choices, *options.each_with_index.map { |option, i| build(:type_de_champ_text, stable_id: 200 + i, condition: ds_include(champ_value(14), constant(option))) }]
    end

    it 'leaves the cluster unenumerated without building the regions' do
      allow(Logic::Domain::Enums).to receive(:new).and_call_original
      expect(Logic::Domain::Enums).not_to receive(:new).with(hash_including(:must_include))
      expect(clusters.first).to be_capped
    end
  end

  context 'with a column value' do
    let(:choice) { build(:type_de_champ_drop_down_list, stable_id: 12, mandatory: true, drop_down_options: ['a', 'b', 'c']) }
    let(:column) { champ_column_value(choice.columns(procedure_id: nil).find { it.type == :enum }) }
    let(:dependent) { build(:type_de_champ_text, stable_id: 13, condition: ds_eq(column, constant('a'))) }
    let(:type_de_champs) { [choice, dependent] }

    it 'reads the column domain' do
      expect(clusters.first.sources.map(&:libelle)).to eq([choice.libelle])
      expect(visible_sets(clusters.first)).to contain_exactly([13], [])
    end

    context 'with the champ also read as a value' do
      let(:by_value) { build(:type_de_champ_text, stable_id: 15, condition: ds_eq(champ_value(12), constant('b'))) }
      let(:type_de_champs) { [choice, dependent, by_value] }

      it 'is a source of its own' do
        expect(clusters.first.sources.map(&:term)).to eq([column, champ_value(12)])
        expect(clusters.first.branches.size).to eq(4)
      end
    end
  end
end
