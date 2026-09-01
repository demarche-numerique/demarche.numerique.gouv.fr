# frozen_string_literal: true

describe Logic::Satisfiability do
  include Logic

  let(:number) { build(:type_de_champ_integer_number, stable_id: 1) }
  let(:choice) { build(:type_de_champ_drop_down_list, stable_id: 2, drop_down_options: ['a', 'b']) }
  let(:yes_no) { build(:type_de_champ_yes_no, stable_id: 3) }
  let(:type_de_champs) { [number, choice, yes_no] }

  let(:n) { champ_value(number.stable_id) }
  let(:c) { champ_value(choice.stable_id) }
  let(:y) { champ_value(yes_no.stable_id) }

  subject(:errors) { described_class.new(type_de_champs).errors(condition) }

  def contradiction(term, atoms) = { type: :contradiction, stable_id: term.stable_id, atoms: }

  context 'with a single atom' do
    let(:condition) { greater_than(n, constant(3)) }

    it { is_expected.to be_empty }
  end

  context 'with a satisfiable conjunction' do
    let(:condition) { ds_and([greater_than(n, constant(2)), less_than(n, constant(5)), ds_eq(c, constant('a'))]) }

    it { is_expected.to be_empty }
  end

  context 'with a contradictory conjunction' do
    let(:condition) { ds_and([greater_than(n, constant(3)), less_than(n, constant(2)), ds_eq(c, constant('a'))]) }

    it { is_expected.to eq([contradiction(n, [greater_than(n, constant(3)), less_than(n, constant(2))])]) }
  end

  context 'with several contradictory variables' do
    let(:condition) { ds_and([ds_eq(n, constant(2)), ds_eq(n, constant(3)), ds_eq(y, constant(true)), ds_eq(y, constant(false))]) }

    it 'reports each of them' do
      expect(errors).to eq([
        contradiction(n, [ds_eq(n, constant(2)), ds_eq(n, constant(3))]),
        contradiction(y, [ds_eq(y, constant(true)), ds_eq(y, constant(false))]),
      ])
    end
  end

  context 'with a disjunction' do
    let(:condition) { ds_or([ds_and([ds_eq(n, constant(2)), ds_eq(n, constant(3))]), ds_eq(c, constant('a'))]) }

    it 'is satisfiable when one branch is' do
      expect(errors).to be_empty
    end
  end

  context 'with a disjunction of contradictions' do
    let(:condition) { ds_or([ds_and([ds_eq(n, constant(2)), ds_eq(n, constant(3))]), ds_and([ds_eq(c, constant('a')), ds_eq(c, constant('b'))])]) }

    it 'reports every branch' do
      expect(errors).to eq([
        contradiction(n, [ds_eq(n, constant(2)), ds_eq(n, constant(3))]),
        contradiction(c, [ds_eq(c, constant('a')), ds_eq(c, constant('b'))]),
      ])
    end
  end

  context 'with a disjunction nested in a conjunction' do
    let(:condition) { ds_and([ds_eq(n, constant(2)), ds_or([ds_eq(n, constant(3)), ds_eq(n, constant(4))])]) }

    it 'distributes' do
      expect(errors).to eq([
        contradiction(n, [ds_eq(n, constant(2)), ds_eq(n, constant(3))]),
        contradiction(n, [ds_eq(n, constant(2)), ds_eq(n, constant(4))]),
      ])
    end
  end

  context 'with terms the domains do not cover' do
    let(:condition) { ds_and([empty_operator(empty, empty), ds_eq(constant(1), constant(2)), ds_eq(champ_value(42), constant(1)), ds_eq(n, constant(2)), ds_eq(n, constant(2))]) }

    it { is_expected.to be_empty }
  end

  context 'with a column value' do
    let(:condition) { ds_and([ds_eq(column, constant('a')), ds_eq(column, constant('b'))]) }
    let(:column) { champ_column_value(choice.columns(procedure_id: nil).find { it.type == :enum }) }

    it { is_expected.to eq([contradiction(column, [ds_eq(column, constant('a')), ds_eq(column, constant('b'))])]) }
  end

  describe 'reachability' do
    let(:hidden) { build(:type_de_champ_drop_down_list, stable_id: 4, drop_down_options: ['x', 'y'], condition: greater_than(n, constant(10))) }
    let(:deeper) { build(:type_de_champ_yes_no, stable_id: 5, condition: ds_eq(champ_value(4), constant('x'))) }
    let(:type_de_champs) { [number, choice, yes_no, hidden, deeper] }
    let(:h) { champ_value(hidden.stable_id) }
    let(:d) { champ_value(deeper.stable_id) }

    context 'when the targeted champ can be displayed' do
      let(:condition) { ds_and([ds_eq(h, constant('x')), greater_than(n, constant(20))]) }

      it { is_expected.to be_empty }
    end

    context 'when the targeted champ is never displayed in that case' do
      let(:condition) { ds_and([ds_eq(h, constant('x')), less_than(n, constant(5))]) }

      it { is_expected.to eq([{ type: :unreachable, stable_id: hidden.stable_id }]) }
    end

    context 'when the display condition is transitive' do
      let(:condition) { ds_and([ds_eq(d, constant(true)), less_than(n, constant(5))]) }

      it { is_expected.to eq([{ type: :unreachable, stable_id: deeper.stable_id }]) }
    end

    context 'when one of the targeted champs kills the condition on its own' do
      let(:other) { build(:type_de_champ_yes_no, stable_id: 6, condition: less_than(n, constant(5))) }
      let(:type_de_champs) { super() + [other] }
      let(:condition) { ds_and([ds_eq(h, constant('x')), ds_eq(champ_value(6), constant(true)), less_than(n, constant(5))]) }

      it 'blames that champ only' do
        expect(errors).to eq([{ type: :unreachable, stable_id: hidden.stable_id }])
      end
    end

    context 'when the targeted champ is read as a column' do
      let(:column) { champ_column_value(hidden.columns(procedure_id: nil).find { it.type == :enum }) }
      let(:condition) { ds_and([ds_eq(column, constant('x')), less_than(n, constant(5))]) }

      it { is_expected.to eq([{ type: :unreachable, stable_id: hidden.stable_id }]) }
    end

    context 'when only the combination of targeted champs is impossible' do
      let(:other) { build(:type_de_champ_yes_no, stable_id: 6, condition: less_than(n, constant(5))) }
      let(:type_de_champs) { super() + [other] }
      let(:condition) { ds_and([ds_eq(h, constant('x')), ds_eq(champ_value(6), constant(true))]) }

      it 'blames every targeted champ' do
        expect(errors).to eq([{ type: :unreachable, stable_id: hidden.stable_id }, { type: :unreachable, stable_id: other.stable_id }])
      end
    end

    context 'when the condition is itself contradictory' do
      let(:condition) { ds_and([ds_eq(h, constant('x')), ds_eq(h, constant('y')), less_than(n, constant(5))]) }

      it 'reports the contradiction only' do
        expect(errors).to eq([contradiction(h, [ds_eq(h, constant('x')), ds_eq(h, constant('y'))])])
      end
    end

    context 'when the display conditions depend on each other' do
      let(:hidden) { build(:type_de_champ_drop_down_list, stable_id: 4, drop_down_options: ['x', 'y'], condition: ds_eq(champ_value(5), constant(true))) }
      let(:condition) { ds_and([ds_eq(d, constant(true)), less_than(n, constant(5))]) }

      it 'ends' do
        expect(errors).to be_empty
      end
    end

    context 'with a long chain of alternatives' do
      let(:type_de_champs) do
        [number] + (1..12).map do |i|
          previous = champ_value(i == 1 ? number.stable_id : 100 + i - 1)
          build(:type_de_champ_integer_number, stable_id: 100 + i, condition: ds_or([ds_eq(previous, constant(1)), ds_eq(previous, constant(2)), ds_eq(previous, constant(3))]))
        end
      end
      let(:condition) { ds_and([ds_eq(champ_value(112), constant(1)), greater_than(n, constant(0))]) }
      let(:checker) { described_class.new(type_de_champs) }

      # 3**12 conjunctions in all: the search must not visit them
      before { allow(checker).to receive(:satisfiable_conjunction?).and_call_original }

      it 'stops at the first satisfiable conjunction' do
        expect(checker.errors(condition)).to be_empty
        expect(checker).to have_received(:satisfiable_conjunction?).at_most(20).times
      end

      context 'when it is dead' do
        let(:condition) { ds_and([ds_eq(champ_value(112), constant(1)), greater_than(n, constant(10))]) }

        it 'prunes the dead branches' do
          expect(checker.errors(condition)).to eq([{ type: :unreachable, stable_id: 112 }])
          expect(checker).to have_received(:satisfiable_conjunction?).at_most(20).times
        end
      end
    end

    context 'with a disjunction over champs displayed in exclusive cases' do
      let(:other) { build(:type_de_champ_yes_no, stable_id: 6, condition: less_than(n, constant(5))) }
      let(:type_de_champs) { super() + [other] }
      let(:condition) { ds_or([ds_eq(h, constant('x')), ds_eq(champ_value(6), constant(true))]) }

      it { is_expected.to be_empty }
    end

    context 'with a disjunction whose branch on the targeted champ is dead' do
      let(:condition) { ds_or([ds_and([ds_eq(h, constant('x')), less_than(n, constant(5))]), less_than(n, constant(3))]) }

      it { is_expected.to be_empty }
    end

    context 'with a disjunction on the targeted champ under a dead conjunction' do
      let(:condition) { ds_and([ds_or([ds_eq(h, constant('x')), ds_eq(h, constant('y'))]), less_than(n, constant(5))]) }

      it { is_expected.to eq([{ type: :unreachable, stable_id: hidden.stable_id }]) }
    end

    context 'with a disjunction that keeps a reachable branch' do
      let(:condition) { ds_or([ds_and([ds_eq(h, constant('x')), less_than(n, constant(5))]), ds_eq(c, constant('a'))]) }

      it { is_expected.to be_empty }
    end
  end
end
