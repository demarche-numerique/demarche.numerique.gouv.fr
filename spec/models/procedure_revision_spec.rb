# frozen_string_literal: true

describe ProcedureRevision do
  let(:draft) { procedure.draft_revision }
  let(:type_de_champ_public) { draft.public_root_type_de_champs.first }
  let(:type_de_champ_private) { draft.private_root_type_de_champs.first }
  let(:type_de_champ_repetition) do
    repetition = draft.public_root_type_de_champs.find(&:repetition?)
    repetition.update(stable_id: 3333)
    # a stable id never changes: the revision has to lay out its types de champ again
    draft.reload
    repetition
  end

  describe '#type_de_champ_tree' do
    context 'on a draft' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ libelle: 'a' }, { libelle: 'b' }, { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }] }]) }

      def stored_tree = ProcedureRevision.find(draft.id).type_de_champ_tree
      def stored_libelles(nodes = stored_tree.public_children) = nodes.map { [TypeDeChamp.find(it.type_de_champ_id).libelle, *stored_libelles(it.children).presence] }

      it 'is empty at creation' do
        created = procedure.revisions.create!

        expect(ProcedureRevision.find(created.id).type_de_champ_tree).to eq(TypeDeChampTree.new)
      end

      it 'is stored with every edit, and holds the ones made through other instances' do
        a = draft.public_root_type_de_champs.first
        draft.add_type_de_champ(type_champ: :text, libelle: 'mine')
        expect(stored_libelles).to eq([['mine'], ['a'], ['b'], ['r', ['r1']]])

        ProcedureRevision.find(draft.id).add_type_de_champ(type_champ: :text, libelle: 'theirs')
        draft.remove_type_de_champ(a.stable_id)

        expect(stored_libelles).to eq([['theirs'], ['mine'], ['b'], ['r', ['r1']]])
      end
    end

    context 'on a published revision' do
      let(:revision) { procedures.individual.published_revision }

      it 'is never null' do
        expect { revision.update_columns(type_de_champ_tree: nil) }
          .to raise_error(ActiveRecord::StatementInvalid, /procedure_revisions_type_de_champ_tree_null/)
      end
    end
  end

  describe 'types de champ laid out from the tree' do
    let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs: [{ libelle: 'd' }]) }
    let(:public_type_de_champs) do
      [
        { libelle: 'a' },
        { type: :header_section, level: 1, libelle: 'h1' },
        { libelle: 'b' },
        { type: :repetition, libelle: 'r', children: [{ type: :header_section, level: 1, libelle: 'rh1' }, { libelle: 'r1' }] },
        { type: :header_section, level: 2, libelle: 'h2' },
        { libelle: 'c' },
      ]
    end

    def libelles(type_de_champs) = type_de_champs.map(&:libelle)
    def laid_out(libelle) = (draft.public_type_de_champs + draft.private_type_de_champs).flat_map { [it, *it.flat_children] }.find { it.libelle == libelle }

    it 'lists them as before' do
      expect(libelles(draft.public_flat_type_de_champs)).to eq(['a', 'h1', 'b', 'r', 'rh1', 'r1', 'h2', 'c'])
      expect(libelles(draft.public_root_type_de_champs)).to eq(['a', 'h1', 'b', 'r', 'h2', 'c'])
      expect(libelles(draft.private_flat_type_de_champs)).to eq(['d'])
      expect(libelles(draft.private_root_type_de_champs)).to eq(['d'])
      expect(libelles(draft.type_de_champs)).to eq(['a', 'h1', 'b', 'r', 'rh1', 'r1', 'h2', 'c', 'd'])
      expect(libelles(laid_out('r').flat_children)).to eq(['rh1', 'r1'])
      expect(laid_out('r1').enclosing_repetition).to eq(laid_out('r'))
      expect(laid_out('b').enclosing_repetition).to be_nil
    end

    it 'lists each one with what sits around it, whatever the header sections' do
      expect(libelles(laid_out('b').flat_siblings)).to eq(['a', 'h1', 'b', 'r', 'h2', 'c'])
      expect(libelles(laid_out('r1').flat_siblings)).to eq(['rh1', 'r1'])
      expect(libelles(laid_out('d').flat_siblings)).to eq(['d'])
    end

    it 'gives each one its children and its ancestors' do
      expect(libelles(draft.public_type_de_champs)).to eq(['a', 'h1'])
      expect(libelles(draft.private_type_de_champs)).to eq(['d'])
      expect(libelles(laid_out('h1').children)).to eq(['b', 'r', 'h2'])
      expect(libelles(laid_out('h1').flat_children)).to eq(['b', 'r', 'rh1', 'r1', 'h2', 'c'])
      expect(libelles(laid_out('r').children)).to eq(['rh1'])
      expect(laid_out('a').children).to be_empty

      r1 = laid_out('r1')
      expect(libelles(r1.ancestors)).to eq(['h1', 'r', 'rh1'])
      expect(r1.parent).to equal(laid_out('rh1'))
      expect(r1.enclosing_repetition).to equal(laid_out('r'))
      expect(r1.enclosing_section).to equal(laid_out('rh1'))
      expect(r1).to be_in_repetition.and be_in_section

      expect(laid_out('r').enclosing_section).to equal(laid_out('h1'))
      expect(laid_out('r')).not_to be_in_repetition
      expect(laid_out('a').parent).to be_nil
      expect(laid_out('a')).not_to be_in_section
    end

    it 'gives each one its level, going on through a repetition' do
      levels = draft.type_de_champs.to_h { [it.libelle, it.level] }

      expect(levels).to eq({ 'a' => 0, 'h1' => 1, 'b' => 1, 'r' => 1, 'rh1' => 2, 'r1' => 2, 'h2' => 2, 'c' => 2, 'd' => 0 })
    end

    it 'finds one by its stable id' do
      expect(draft.type_de_champ(laid_out('r1').stable_id)).to equal(laid_out('r1'))
      expect(draft.type_de_champ(laid_out('r1').stable_id.to_s)).to equal(laid_out('r1'))
      expect(draft.type_de_champ(0)).to be_nil
    end

    it 'follows the edits' do
      added = draft.add_type_de_champ(type_champ: :text, libelle: 'r2', parent_stable_id: laid_out('r').stable_id, after_stable_id: laid_out('r1').stable_id)

      expect(libelles(draft.type_de_champ(added.stable_id).ancestors)).to eq(['h1', 'r', 'rh1'])

      draft.remove_type_de_champ(laid_out('rh1').stable_id)

      expect(libelles(laid_out('r').children)).to eq(['r1', 'r2'])
    end

    it 'lays them out again once reloaded' do
      TypeDeChamp.find(laid_out('a').id).update!(libelle: 'a2')

      expect(libelles(draft.public_type_de_champs)).to eq(['a', 'h1'])
      expect(libelles(draft.reload.public_type_de_champs)).to eq(['a2', 'h1'])
    end

    it 'gives each one its position among the children of its parent' do
      positions = ['a', 'h1', 'b', 'r', 'h2', 'c', 'rh1', 'r1', 'd'].index_with { laid_out(it).position }

      expect(positions).to eq('a' => 0, 'h1' => 1, 'b' => 0, 'r' => 1, 'h2' => 2, 'c' => 0, 'rh1' => 0, 'r1' => 0, 'd' => 0)
    end

    it 'tells each one the revision that laid it out' do
      expect(laid_out('r1').revision).to equal(draft)
      expect { procedure.aggregated_type_de_champs.type_de_champ(laid_out('r1').stable_id).revision }.to raise_error(TypeDeChamp::NotLaidOutError)
    end

    it 'leaves the other instances alone' do
      expect { TypeDeChamp.find(laid_out('r').id).children }.to raise_error(TypeDeChamp::NotLaidOutError)
      expect { laid_out('r').dup.children }.to raise_error(TypeDeChamp::NotLaidOutError)
      expect { laid_out('r').dup.position }.to raise_error(TypeDeChamp::NotLaidOutError)
      expect { laid_out('r').dup.revision }.to raise_error(TypeDeChamp::NotLaidOutError)
      expect { draft.dup.public_type_de_champs }.to raise_error(ArgumentError)
    end

    context 'with a type de champ held by two revisions' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }, { libelle: 'r2' }] }]) }
      let(:published) { procedure.published_revision }

      before { draft.remove_type_de_champ(draft.type_de_champs.find { it.libelle == 'r2' }.stable_id) }

      it 'lays it out in each of them' do
        expect(published.type_de_champ(laid_out('r').stable_id)).to eq(laid_out('r'))

        expect(libelles(laid_out('r').children)).to eq(['r1'])
        expect(libelles(published.type_de_champ(laid_out('r').stable_id).children)).to eq(['r1', 'r2'])
        expect(libelles(laid_out('r').children)).to eq(['r1'])
      end

      it 'lays it out in each of them when preloaded together' do
        ProcedureRevision.preload_type_de_champs([published, draft])

        expect(published.type_de_champ(laid_out('r').stable_id)).not_to equal(laid_out('r'))
        expect(libelles(laid_out('r').children)).to eq(['r1'])
        expect(libelles(published.type_de_champ(laid_out('r').stable_id).children)).to eq(['r1', 'r2'])
      end
    end

    describe '.preload_type_de_champs' do
      let(:other_procedure) { create(:procedure, public_type_de_champs: [{ libelle: 'z' }]) }

      def queries
        queries = []
        callback = lambda { |*args| queries << args.last[:sql] if args.last[:sql].include?('FROM "types_de_champ"') }
        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
        queries
      end

      it 'lays out several revisions in one query' do
        revisions = ProcedureRevision.where(id: [draft.id, other_procedure.draft_revision_id]).to_a

        expect(queries { ProcedureRevision.preload_type_de_champs(revisions) }.size).to eq(1)
        expect(queries { expect(revisions.map { libelles(it.type_de_champs) }).to contain_exactly(['a', 'h1', 'b', 'r', 'rh1', 'r1', 'h2', 'c', 'd'], ['z']) }).to be_empty
      end

      it 'loads once the types de champ several revisions hold' do
        procedure.publish_revision!(procedure.administrateurs.first)
        revisions = [procedure.published_revision, procedure.draft_revision]

        expect(queries { ProcedureRevision.preload_type_de_champs(revisions) }.size).to eq(1)

        published_type_de_champ, draft_type_de_champ = revisions.map { |revision| revision.type_de_champs.find { it.libelle == 'r' } }
        expect(published_type_de_champ).to eq(draft_type_de_champ)
        expect(published_type_de_champ).not_to equal(draft_type_de_champ)
        expect(draft_type_de_champ).to be_a(TypesDeChamp::RepetitionTypeDeChamp)
        expect(libelles(draft_type_de_champ.flat_children)).to eq(['rh1', 'r1'])

        draft_type_de_champ.libelle = 'changed'
        expect(published_type_de_champ.libelle).to eq('r')
      end

      it 'lays out every instance of one revision' do
        revisions = [draft, ProcedureRevision.find(draft.id)]

        expect(queries { ProcedureRevision.preload_type_de_champs(revisions) }.size).to eq(1)
        expect(queries { revisions.each(&:type_de_champs) }).to be_empty
        expect(revisions.first.type_de_champs.first).not_to equal(revisions.last.type_de_champs.first)
      end
    end

    it 'leaves out a type de champ purged since the tree was read' do
      stable_id = TypeDeChamp.find_by!(id: draft.type_de_champ_tree.type_de_champ_ids, libelle: 'r').stable_id
      ProcedureRevision.find(draft.id).remove_type_de_champ(stable_id)
      # as a publication purges the types de champ no revision lays out
      procedure.type_de_champs.where(libelle: ['r', 'rh1', 'r1']).destroy_all

      expect(libelles(draft.public_type_de_champs.flat_map { [it, *it.flat_children] })).to eq(['a', 'h1', 'b', 'h2', 'c'])
      expect(laid_out('h2').position).to eq(1)
    end

    it 'lays out again after a layout failed' do
      allow(TypeDeChampLayout).to receive(:lay_out).and_raise(ActiveRecord::QueryCanceled)
      expect { draft.public_type_de_champs }.to raise_error(ActiveRecord::QueryCanceled)

      allow(TypeDeChampLayout).to receive(:lay_out).and_call_original
      expect(libelles(draft.public_type_de_champs)).to eq(['a', 'h1'])
    end

    context 'with a revision not saved yet' do
      let(:procedure) { build(:procedure, public_type_de_champs:) }

      it 'waits for its types de champ to have a stable id' do
        expect { draft.public_type_de_champs }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#create_new_revision' do
    let(:new_draft) { procedure.create_new_revision }

    context 'from a simple procedure' do
      let(:procedure) { create(:procedure) }

      it 'should be part of procedure' do
        expect(new_draft.procedure).to eq(draft.procedure)
        expect(procedure.revisions.count).to eq(2)
        expect(procedure.revisions).to eq([draft, new_draft])
      end
    end

    context 'with simple tdc' do
      let(:procedure) { create(:procedure, :with_type_de_champ, :with_type_de_champ_private) }

      it 'should have the same tdcs, laid out on its own' do
        expect(new_draft.public_root_type_de_champs.count).to eq(1)
        expect(new_draft.private_root_type_de_champs.count).to eq(1)
        expect(new_draft.public_root_type_de_champs).to eq(draft.public_root_type_de_champs)
        expect(new_draft.private_root_type_de_champs).to eq(draft.private_root_type_de_champs)

        expect(new_draft.public_root_type_de_champs.first).not_to equal(draft.public_root_type_de_champs.first)
        expect(new_draft.private_root_type_de_champs.first).not_to equal(draft.private_root_type_de_champs.first)
      end
    end

    context 'with repetition_type_de_champ' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, children: [{ type: :text }, { type: :integer_number }] }]) }

      it 'should have the same tdcs, laid out on its own' do
        expect(new_draft.type_de_champs.count).to eq(3)
        expect(new_draft.type_de_champs).to eq(draft.type_de_champs)

        new_repetition, new_child = new_draft.type_de_champs.partition(&:repetition?).map(&:first)

        expect(new_child.parent).to equal(new_repetition)
        expect(new_repetition).not_to equal(draft.type_de_champs.find(&:repetition?))
      end
    end

    context 'with a header section, a repetition and an annotation' do
      let(:procedure) do
        create(:procedure,
          public_type_de_champs: [
            { type: :header_section, level: 1, libelle: 'h1' },
            { libelle: 'a' },
            { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }, { libelle: 'r2' }] },
          ],
          private_type_de_champs: [{ libelle: 'c' }])
      end

      it 'takes the tree as it is' do
        expect { new_draft }.not_to change { procedure.type_de_champs.count }

        expect(new_draft.reload.type_de_champ_tree).to eq(draft.type_de_champ_tree)
        expect(new_draft.type_de_champs.map { [it.libelle, it.position, it.parent&.libelle] }).to eq([
          ['h1', 0, nil], ['a', 0, 'h1'], ['r', 1, 'h1'], ['r1', 0, 'r'], ['r2', 1, 'r'], ['c', 0, nil],
        ])
      end
    end
  end

  describe 'ineligibilite_rules_are_valid?' do
    include Logic
    let(:procedure) { create(:procedure) }
    let(:draft_revision) { procedure.draft_revision }
    let(:ineligibilite_message) { 'ok' }
    let(:ineligibilite_enabled) { true }
    before do
      procedure.draft_revision.update(ineligibilite_rules:, ineligibilite_message:, ineligibilite_enabled:)
    end

    context 'when ineligibilite_rules are valid' do
      let(:ineligibilite_rules) { ds_eq(constant(true), constant(true)) }
      it 'is valid' do
        expect(draft_revision.validate(:publication)).to be_truthy
        expect(draft_revision.validate(:ineligibilite_rules_editor)).to be_truthy
      end
    end

    context 'when ineligibilite_rules are invalid on simple champ' do
      let(:ineligibilite_rules) { ds_eq(constant(true), constant(1)) }
      it 'is invalid when rule is incorrect' do
        expect(draft_revision.validate(:publication)).to be_falsey
        expect(draft_revision.validate(:ineligibilite_rules_editor)).to be_falsey
      end
    end

    context 'when ineligibilite_rules are invalid on simple champ' do
      let(:ineligibilite_rules) { empty_operator(empty, empty) }
      it 'is invalid when rule is empty' do
        expect(draft_revision.validate(:publication)).to be_falsey
        expect(draft_revision.validate(:ineligibilite_rules_editor)).to be_falsey
      end
    end

    context 'when ineligibilite_rules can never be true' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :integer_number }]) }
      let(:tdc_number) { draft_revision.public_flat_type_de_champs.first }
      let(:ineligibilite_rules) { ds_and([greater_than(champ_value(tdc_number.stable_id), constant(3)), less_than(champ_value(tdc_number.stable_id), constant(2))]) }

      it 'is invalid' do
        draft_revision.validate(:publication)
        expect(draft_revision.errors).to be_of_kind(:ineligibilite_rules, :invalid)

        draft_revision.validate(:ineligibilite_rules_editor)
        expect(draft_revision.errors).to be_of_kind(:ineligibilite_rules, :invalid)
      end

      context 'when ineligibilite is disabled' do
        let(:ineligibilite_enabled) { false }

        it 'is valid: leftover rules do not block publication' do
          expect(draft_revision.validate(:publication)).to be_truthy
          expect(draft_revision.validate(:ineligibilite_rules_editor)).to be_truthy
        end
      end
    end

    context 'when ineligibilite_rules are invalid on repetition champ' do
      let(:ineligibilite_rules) { ds_eq(constant(true), constant(1)) }
      let(:procedure) { create(:procedure, public_type_de_champs:) }
      let(:public_type_de_champs) { [{ type: :repetition, children: [{ type: :integer_number }] }] }
      let(:tdc_number) { draft_revision.public_flat_type_de_champs.find { _1.type_champ == 'integer_number' } }
      let(:ineligibilite_rules) do
        ds_eq(champ_value(tdc_number.stable_id), constant(true))
      end
      it 'is invalid' do
        expect(draft_revision.validate(:publication)).to be_falsey
        expect(draft_revision.validate(:ineligibilite_rules_editor)).to be_falsey
      end
    end
  end

  describe '#champ_value_in_condition?' do
    include Logic
    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { type: :yes_no, libelle: 'gate' },
        { type: :integer_number, libelle: 'value' },
      ])
    end
    let(:gate_tdc) { draft.public_root_type_de_champs.first }
    let(:value_tdc) { draft.public_root_type_de_champs.second }
    let(:gate_column) { procedure.find_column(label: 'gate') }

    subject { procedure.reload.draft_revision.champ_value_in_condition? }

    context 'when no tdc has a condition' do
      it { is_expected.to be(false) }
    end

    context 'when a tdc condition uses a champ_value' do
      before { value_tdc.update!(condition: ds_eq(champ_value(gate_tdc.stable_id), constant(true))) }

      it { is_expected.to be(true) }
    end

    context 'when a tdc condition uses only a champ_column_value' do
      before { value_tdc.update!(condition: ds_eq(champ_column_value(gate_column), constant(true))) }

      it { is_expected.to be(false) }
    end

    context 'when a champ_value is nested deep inside an And' do
      before do
        value_tdc.update!(condition: ds_and([
          ds_eq(champ_column_value(gate_column), constant(true)),
          ds_eq(champ_value(gate_tdc.stable_id), constant(true)),
        ]))
      end

      it { is_expected.to be(true) }
    end

    context 'when ineligibilite_rules use a champ_value' do
      before { draft.update!(ineligibilite_rules: ds_eq(champ_value(gate_tdc.stable_id), constant(true))) }

      it { is_expected.to be(true) }
    end

    context 'when ineligibilite_rules use only a champ_column_value' do
      before { draft.update!(ineligibilite_rules: ds_eq(champ_column_value(gate_column), constant(true))) }

      it { is_expected.to be(false) }
    end
  end

  describe 'the children of a repetition' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, children: [{ type: :text }, { type: :integer_number }] }]) }
    let!(:parent) { draft.type_de_champs.find(&:repetition?) }
    let!(:first_child) { draft.type_de_champs.reject(&:repetition?).first }
    let!(:second_child) { draft.type_de_champs.reject(&:repetition?).second }

    def children_in(revision) = revision.type_de_champ(parent.stable_id).flat_children

    it { expect(children_in(draft)).to match([first_child, second_child]) }

    context 'with multiple child' do
      # the last one is added first
      let!(:last_child) { draft.add_type_de_champ(type_champ: :text, libelle: 'last', after_stable_id: second_child.stable_id) }
      let!(:third_child) { draft.add_type_de_champ(type_champ: :text, libelle: 'third', after_stable_id: second_child.stable_id) }

      it 'returns the children in order' do
        expect(children_in(draft)).to eq([first_child, second_child, third_child, last_child])
      end
    end

    context 'with multiple revision' do
      let(:new_draft) do
        procedure.publish!(procedure.administrateurs.first)
        procedure.draft_revision
      end
      # the copy the draft makes of a type de champ the published revision holds
      let!(:new_child) { new_draft.find_and_ensure_exclusive_use(first_child.stable_id) }

      it 'returns the children regarding the revision' do
        expect(new_child.id).not_to eq(first_child.id)
        expect(children_in(draft)).to match([first_child, second_child])
        expect(children_in(new_draft)).to match([new_child, second_child])
      end
    end
  end

  describe '#estimated_fill_duration' do
    let(:mandatory) { true }
    let(:description) { nil }
    let(:description_read_time) { ((description || "").split.size / TypeDeChamp::READ_WORDS_PER_SECOND).round }

    let(:public_type_de_champs) do
      [
        { mandatory: true, description: },
        { type: :siret, mandatory: true, description: },
        { type: :piece_justificative, mandatory:, description: },
      ]
    end
    let(:procedure) { create(:procedure, public_type_de_champs: public_type_de_champs) }

    subject { procedure.active_revision.estimated_fill_duration }

    it 'sums the durations of public champs' do
      expect(subject).to eq \
          TypeDeChamp::FILL_DURATION_SHORT \
        + TypeDeChamp::FILL_DURATION_MEDIUM \
        + TypeDeChamp::FILL_DURATION_LONG \
        + 3 * description_read_time
    end

    context 'when some champs are optional' do
      let(:mandatory) { false }

      it 'estimates that half of optional champs will be filled' do
        expect(subject).to eq \
            TypeDeChamp::FILL_DURATION_SHORT \
          + TypeDeChamp::FILL_DURATION_MEDIUM \
          + 2 * description_read_time \
          + (description_read_time + TypeDeChamp::FILL_DURATION_LONG) / 2
      end
    end

    context 'when some champs have a description' do
      let(:description) { "some four words description" }

      it 'estimates that duration includes description reading time' do
        expect(subject).to eq \
            TypeDeChamp::FILL_DURATION_SHORT \
          + TypeDeChamp::FILL_DURATION_MEDIUM \
          + TypeDeChamp::FILL_DURATION_LONG \
          + 3 * description_read_time
      end
    end

    context 'when there are repetitions' do
      let(:public_type_de_champs) do
        [
          {
            type: :repetition,
            mandatory: true,
            description:,
            children: [
              { mandatory: true, description: "word " * 10 },
              { type: :piece_justificative, mandatory: true, description: nil },
            ],
          },
        ]
      end

      it 'estimates that between 2 and 3 rows will be filled for each repetition' do
        repetable_block_read_duration = description_read_time

        row_duration = TypeDeChamp::FILL_DURATION_SHORT + TypeDeChamp::FILL_DURATION_LONG
        children_read_duration = (10 / TypeDeChamp::READ_WORDS_PER_SECOND).round

        expect(subject).to eq repetable_block_read_duration + row_duration * 2.5 + children_read_duration
      end
    end

    context 'when there are non fillable champs' do
      let(:public_type_de_champs) do
        [
          {
            type: :explication,
            description: "5 words description <strong>containing html</strong> " * 20,
          },
          { mandatory: true, description: nil },
        ]
      end

      it 'estimates duration based on content reading' do
        expect(subject).to eq((100 / TypeDeChamp::READ_WORDS_PER_SECOND).round + TypeDeChamp::FILL_DURATION_SHORT)
      end
    end

    describe 'caching behavior', caching: true do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: public_type_de_champs) }

      context 'when a type de champ belonging to a draft revision is updated' do
        let(:draft_revision) { procedure.draft_revision }

        before do
          draft_revision.estimated_fill_duration
          draft_revision.type_de_champs.first.update!(type_champ: TypeDeChamp.type_champs.fetch(:piece_justificative))
          draft_revision.reload
        end

        it 'returns an up-to-date estimate' do
          expect(draft_revision.estimated_fill_duration).to eq \
              TypeDeChamp::FILL_DURATION_LONG \
            + TypeDeChamp::FILL_DURATION_MEDIUM \
            + TypeDeChamp::FILL_DURATION_LONG \
            + 3 * description_read_time
        end
      end

      context 'when the revision is published (and thus immutable)' do
        let(:published_revision) { procedure.published_revision }

        it 'caches the estimate' do
          expect(published_revision).to receive(:compute_estimated_fill_duration).once
          published_revision.estimated_fill_duration
          published_revision.estimated_fill_duration
        end
      end
    end
  end

  describe 'conditions_are_valid' do
    include Logic

    let(:procedure) { create(:procedure, public_type_de_champs:) }
    let(:public_type_de_champs) do
      [
        { type: :integer_number, libelle: 'l1' },
        { type: :integer_number, libelle: 'l2' },
      ]
    end
    def first_champ = procedure.draft_revision.public_root_type_de_champs.first
    def second_champ = procedure.draft_revision.public_root_type_de_champs.second

    let(:draft_revision) { procedure.draft_revision }
    let(:condition) { nil }

    subject do
      procedure.validate(:publication)
      procedure.errors
    end

    context 'when a champ has a valid condition (type)' do
      before { second_champ.update(condition: condition) }
      let(:condition) { ds_eq(constant(true), constant(true)) }

      it { is_expected.to be_empty }
    end

    context 'when a champ has a valid condition: needed tdc is up in the forms' do
      before { second_champ.update(condition: condition) }
      let(:condition) { ds_eq(champ_value(first_champ.stable_id), constant(1)) }

      it { is_expected.to be_empty }
    end

    context 'when a champ has an invalid condition' do
      before { second_champ.update(condition: condition) }
      let(:condition) { ds_eq(constant(true), constant(1)) }

      it { expect(subject.first.attribute).to eq(:public_draft_type_de_champs) }
    end

    context 'when a champ has an invalid condition: needed tdc is down in the forms' do
      let(:need_second_champ) { ds_eq(constant('oui'), champ_value(second_champ.stable_id)) }

      before do
        second_champ.update(condition: condition)
        first_champ.update(condition: need_second_champ)
      end

      it { expect(subject.first.attribute).to eq(:public_draft_type_de_champs) }
    end

    context 'with a repetition' do
      let(:procedure) do
        create(:procedure,
               public_type_de_champs: [{ type: :repetition, children: [{ type: :integer_number }, { type: :text }] }])
      end

      let(:children_of_repetition) do
        repetition = procedure.draft_revision.public_root_type_de_champs.find(&:repetition?)
        procedure.draft_revision.type_de_champ(repetition.stable_id).flat_children
      end

      let(:integer_champ) { children_of_repetition.first }
      let(:text_champ) { children_of_repetition.last }

      before { text_champ.update(condition: condition) }

      context 'when a child champ has a valid condition' do
        let(:condition) { ds_eq(champ_value(integer_champ.stable_id), constant(1)) }

        it { is_expected.to be_empty }
      end

      context 'when a champ belongs to a repetition' do
        let(:condition) { ds_eq(champ_value(-1), constant(1)) }

        it { expect(subject.first.attribute).to eq(:public_draft_type_de_champs) }
      end
    end
  end

  describe "expressions_regulieres_are_valid" do
    let(:procedure) do
      create(:procedure).tap do |p|
        p.draft_revision.add_type_de_champ(type_champ: :formatted, libelle: 'exemple', formatted_mode: 'advanced', expression_reguliere:, expression_reguliere_exemple_text:)
      end
    end
    let(:draft_revision) { procedure.draft_revision }

    subject do
      procedure.validate(:publication)
      procedure.errors
    end

    context "When no regexp and no example" do
      let(:expression_reguliere_exemple_text) { nil }
      let(:expression_reguliere) { nil }

      it { is_expected.to be_empty }
    end

    context "When expression_reguliere but no example" do
      let(:expression_reguliere) { "[A-Z]+" }
      let(:expression_reguliere_exemple_text) { nil }

      it { is_expected.to be_empty }
    end

    context "When expression_reguliere and bad example" do
      let(:expression_reguliere_exemple_text) { "01234567" }
      let(:expression_reguliere) { "[A-Z]+" }

      it { is_expected.not_to be_empty }
    end

    context "When expression_reguliere and good example" do
      let(:expression_reguliere_exemple_text) { "A" }
      let(:expression_reguliere) { "[A-Z]+" }
      it { is_expected.to be_empty }
    end

    context "When bad expression_reguliere" do
      let(:expression_reguliere_exemple_text) { "0123456789" }
      let(:expression_reguliere) { "(" }

      it { is_expected.not_to be_empty }
    end

    context "When repetition" do
      let(:procedure) do
        create(:procedure,
          public_type_de_champs: [{ type: :repetition, children: [{ type: :formatted, formatted_mode: 'advanced', expression_reguliere:, expression_reguliere_exemple_text: }] }])
      end

      context "When bad expression_reguliere" do
        let(:expression_reguliere_exemple_text) { "0123456789" }
        let(:expression_reguliere) { "(" }

        it { is_expected.not_to be_empty }
      end

      context "When expression_reguliere and bad example" do
        let(:expression_reguliere_exemple_text) { "01234567" }
        let(:expression_reguliere) { "[A-Z]+" }

        it { is_expected.not_to be_empty }
      end
    end
  end

  describe "#dependent_conditions" do
    include Logic

    def first_champ = procedure.draft_revision.public_root_type_de_champs.first
    def second_champ = procedure.draft_revision.public_root_type_de_champs.second

    let(:procedure) do
      create(:procedure, public_type_de_champs: [{ type: :integer_number, libelle: 'l1' }]).tap do |p|
        tdc = p.draft_revision.public_root_type_de_champs.last
        p.draft_revision.add_type_de_champ(type_champ: :integer_number,
                                           libelle: 'l2',
                                           condition: ds_eq(champ_value(tdc.stable_id), constant(true)),
                                           after_stable_id: tdc.stable_id)
      end
    end

    it do
      expect(draft.dependent_conditions(first_champ)).to eq([second_champ])
      expect(draft.dependent_conditions(second_champ)).to eq([])
    end

    context 'when a private annotation has a condition on a public champ' do
      let(:procedure) do
        create(:procedure, public_type_de_champs: [{ type: :integer_number, libelle: 'public' }]).tap do |p|
          public_tdc = p.draft_revision.public_root_type_de_champs.first
          p.draft_revision.add_type_de_champ(type_champ: :text,
                                             libelle: 'annotation',
                                             private: true,
                                             condition: ds_eq(champ_value(public_tdc.stable_id), constant(1)))
        end
      end

      def public_champ = procedure.draft_revision.public_root_type_de_champs.first
      def private_annotation = procedure.draft_revision.private_root_type_de_champs.first

      it 'finds the private annotation as dependent' do
        expect(draft.dependent_conditions(public_champ)).to include(private_annotation)
      end
    end
  end

  describe '#used_by_a_condition?' do
    include Logic

    # Flag éteint : la dépendance vaut quelle que soit la porte d'entrée de l'éditeur.
    let(:procedure) do
      create(:procedure,
             public_type_de_champs: [{ type: :text, libelle: 'conditionnel', stable_id: 1, condition: ds_eq(champ_value(2), constant(true)) }],
             private_type_de_champs: [{ type: :yes_no, libelle: 'annotation', stable_id: 2 }])
    end

    it 'finds a private annotation gating a public champ' do
      expect(draft.used_by_a_condition?(type_de_champ_private)).to be true
    end
  end

  describe '#simple_routable_type_de_champs' do
    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { type: :text, libelle: 'l1' },
        { type: :drop_down_list, libelle: 'l2' },
        { type: :departements, libelle: 'l3' },
        { type: :regions, libelle: 'l4' },
        { type: :communes, libelle: 'l5' },
        { type: :epci, libelle: 'l6' },
      ])
    end

    it { expect(draft.simple_routable_type_de_champs.pluck(:libelle)).to eq(['l2', 'l3', 'l4', 'l5', 'l6']) }
  end
end
