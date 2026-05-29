# frozen_string_literal: true

describe Logic::ColumnValue do
  include Logic

  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no, libelle: 'yes' }]) }
  let(:column) { procedure.find_column(label: 'yes') }
  let(:column_value) { Logic::ColumnValue.new(column) }

  describe '#compute' do
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }

    before { champ.update(value: 'true') }

    it { expect(column_value.compute([champ])).to be(true) }

    context 'when the targeted champ is not visible' do
      before { allow(champ).to receive(:visible?).and_return(false) }

      it { expect(column_value.compute([champ])).to be_nil }
    end

    context 'when the targeted champ is blank' do
      before { champ.update(value: nil) }

      it { expect(column_value.compute([champ])).to be_nil }
    end

    context 'when the targeted champ is missing from the list' do
      it { expect(column_value.compute([])).to be_nil }
    end
  end

  # Preserves parity with Logic::ChampValue: a condition on a drop_down_list with
  # "other" enabled compares against the OTHER sentinel, not the human label
  # surfaced by ChampColumn#value in the dashboard.
  describe '#compute with a drop_down_list with other enabled' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :drop_down_list, libelle: 'menu', drop_down_other: true },
      ])
    end
    let(:column) { procedure.find_column(label: 'menu') }
    let(:column_value) { Logic::ColumnValue.new(column) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }

    context "when the user picked 'other' without typing a value" do
      before { champ.update!(value: Champs::DropDownListChamp::OTHER) }

      it { expect(column_value.compute([champ])).to eq(Champs::DropDownListChamp::OTHER) }
    end

    context "when the user picked 'other' and typed a custom value" do
      before do
        champ.update!(value: Champs::DropDownListChamp::OTHER)
        champ.update!(value_other: 'ma valeur')
      end

      it { expect(column_value.compute([champ])).to eq(Champs::DropDownListChamp::OTHER) }
    end
  end

  describe '#sources' do
    it { expect(column_value.sources).to eq([column.stable_id]) }
  end

  describe '#errors' do
    it do
      expect(column_value.errors(procedure.active_revision.types_de_champ)).to eq([])
      expect(column_value.errors([])).to eq([{ type: :not_available }])
    end
  end

  describe '#type' do
    let(:draft_tdcs) { procedure.draft_revision.types_de_champ }
    subject { Logic::ColumnValue.new(procedure.find_column(label:)).type(draft_tdcs) }

    context 'integer column' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :integer_number, libelle: 'n' }]) }
      let(:label) { 'n' }

      it { is_expected.to eq(:number) }
    end

    context 'decimal column' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :decimal_number, libelle: 'd' }]) }
      let(:label) { 'd' }

      it { is_expected.to eq(:number) }
    end

    context 'yes_no column' do
      let(:label) { 'yes' }

      it { is_expected.to eq(:boolean) }
    end

    context 'drop_down_list column' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :drop_down_list, libelle: 'menu' }]) }
      let(:label) { 'menu' }

      it { is_expected.to eq(:enum) }

      context 'when a tdc has changed between revision' do
        let(:stable_id) { procedure.active_revision.types_de_champ.first.stable_id }

        before do
          procedure.draft_revision
            .find_and_ensure_exclusive_use(stable_id)
            .update(type_champ: 'multiple_drop_down_list')
        end

        it { is_expected.to eq(:enums) }
      end
    end
  end

  describe '#options' do
    describe 'when there are different revision' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [linked_drop_down]) }
      let(:draft_tdcs) { procedure.draft_revision.types_de_champ }
      let(:linked_drop_down) do
        { type: :linked_drop_down_list, libelle: 'linked', drop_down_options: }
      end
      let(:drop_down_options) { ['--1--', 'A', '--2--', 'B'] }
      let(:linked_drop_down_stable_id) { procedure.active_revision.types_de_champ.first.stable_id }
      let(:column) { procedure.find_column(label: 'linked (Secondaire)') }
      let(:column_value) { Logic::ColumnValue.new(column) }

      before do
        procedure.draft_revision
          .find_and_ensure_exclusive_use(linked_drop_down_stable_id).update(drop_down_options: ['--1--', 'A', '--2--', 'C'])
      end

      it 'are based on the tdc given as arg' do
        expect(column_value.options(draft_tdcs).map(&:first)).to eq(['A', 'C'])
      end
    end
  end

  describe '#to_s' do
    it { expect(column_value.to_s(procedure.active_revision.types_de_champ)).to eq(column.label) }
  end

  describe 'serialization round-trip' do
    it 'rebuilds an equal ColumnValue from to_h' do
      rebuilt = Logic::ColumnValue.from_h(column_value.to_h)

      expect(rebuilt).to eq(column_value)
      expect(rebuilt.sources).to eq(column_value.sources)
    end

    it 'rebuilds an equal ColumnValue from to_json (Logic.from_json)' do
      rebuilt = Logic.from_json(column_value.to_json)

      expect(rebuilt).to eq(column_value)
    end
  end

  describe '#==' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :yes_no, libelle: 'yes' },
        { type: :integer_number, libelle: 'n' },
      ])
    end

    it 'is equal to another ColumnValue pointing to the same column' do
      other = Logic::ColumnValue.new(procedure.find_column(label: 'yes'))

      expect(column_value).to eq(other)
    end

    it 'is not equal to a ColumnValue pointing to another column' do
      other = Logic::ColumnValue.new(procedure.find_column(label: 'n'))

      expect(column_value).not_to eq(other)
    end

    it 'is not equal to a ChampValue, even with the same stable_id' do
      expect(column_value).not_to eq(Logic::ChampValue.new(column.stable_id))
    end
  end

  describe 'when the underlying column has disappeared' do
    let(:h_id) { { procedure_id: 999_999, column_id: "type_de_champ/123" } }
    let(:broken) { Logic::ColumnValue.from_h({ "term" => "Logic::ColumnValue", "column_id" => h_id }) }

    it 'does not raise on from_h' do
      expect { broken }.not_to raise_error
    end

    it do
      expect(broken.compute([])).to be_nil
      expect(broken.type([])).to eq(:unmanaged)
      expect(broken.options([])).to eq([])
      expect(broken.sources).to eq([])
      expect(broken.to_s([])).to be_nil
    end

    it 'errors always returns :not_available, regardless of the tdcs passed' do
      expect(broken.errors([])).to eq([{ type: :not_available }])
      expect(broken.errors(procedure.active_revision.types_de_champ)).to eq([{ type: :not_available }])
    end

    it 'to_h preserves the original h_id (no nesting / no wrapping leak)' do
      expect(broken.to_h).to eq({ "term" => "Logic::ColumnValue", "column_id" => h_id })
    end

    it 'survives multiple save/reload cycles without growing nested wrappers' do
      twice_round_tripped = Logic::ColumnValue.from_h(broken.to_h)

      expect(twice_round_tripped.to_h).to eq(broken.to_h)
    end

    it 'two broken ColumnValues with the same h_id are equal' do
      other = Logic::ColumnValue.from_h({ "term" => "Logic::ColumnValue", "column_id" => h_id })

      expect(broken).to eq(other)
    end
  end
end
