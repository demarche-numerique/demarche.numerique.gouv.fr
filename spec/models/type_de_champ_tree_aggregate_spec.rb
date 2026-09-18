# frozen_string_literal: true

describe TypeDeChampTree, '.aggregate' do
  let(:procedure) do
    create(:procedure, :published, public_type_de_champs: [
      { type: :text, libelle: 'intro' },
      { type: :repetition, libelle: 'rep', children: [{ libelle: 'r1' }, { libelle: 'r2' }] },
      { type: :header_section, level: 1, libelle: 'S1' },
      { type: :text, libelle: 'a' },
      { type: :header_section, level: 1, libelle: 'S2' },
      { type: :text, libelle: 'b' },
    ], private_type_de_champs: [{ libelle: 'annotation' }])
  end
  let(:administrateur) { procedure.administrateurs.first }
  let(:published_revisions) { procedure.revisions.where.not(id: procedure.draft_revision_id).order(:id) }
  let(:aggregate) { described_class.aggregate(published_revisions.map(&:type_de_champ_tree)) }

  def stable_id(libelle) = TypeDeChamp.where(id: procedure.revisions.joins(:revision_type_de_champs).select(:type_de_champ_id)).find_by!(libelle:).stable_id
  def draft = procedure.draft_revision
  def publish = procedure.publish_revision!(administrateur).then { procedure.reload }

  # the layout as nested libelles of the first version of each type de champ
  def layout(nodes)
    @libelles ||= TypeDeChamp.where(id: procedure.revisions.joins(:revision_type_de_champs).select(:type_de_champ_id)).order(:id).pluck(:stable_id, :libelle).reverse.to_h
    nodes.map { it.children.empty? ? @libelles.fetch(it.stable_id) : { @libelles.fetch(it.stable_id) => layout(it.children) } }
  end

  it 'is empty without any tree' do
    expect(described_class.aggregate([])).to eq(described_class.new)
  end

  it 'mirrors a single tree' do
    expect(aggregate).to eq(procedure.published_revision.type_de_champ_tree)
    expect(layout(aggregate.public_children)).to eq(['intro', { 'rep' => ['r1', 'r2'] }, { 'S1' => ['a'] }, { 'S2' => ['b'] }])
    expect(layout(aggregate.private_children)).to eq(['annotation'])
  end

  context 'when a type de champ was removed from its section' do
    before do
      draft.remove_type_de_champ(stable_id('a'))
      publish
    end

    it 'keeps it at the end of its last-known section' do
      expect(layout(aggregate.public_children)).to eq(['intro', { 'rep' => ['r1', 'r2'] }, { 'S1' => ['a'] }, { 'S2' => ['b'] }])
    end

    it 'lays it after what the section holds in the newest revision' do
      draft.add_type_de_champ(type_champ: :text, libelle: 'c', after_stable_id: stable_id('S1'))
      publish

      expect(layout(aggregate.public_children)).to eq(['intro', { 'rep' => ['r1', 'r2'] }, { 'S1' => ['c', 'a'] }, { 'S2' => ['b'] }])
    end
  end

  context 'when a section was removed with its content' do
    before do
      draft.remove_type_de_champ(stable_id('S1'))
      draft.remove_type_de_champ(stable_id('a'))
      publish
    end

    it 'lays the section at the end, with the content removed along with it' do
      expect(layout(aggregate.public_children)).to eq(['intro', { 'rep' => ['r1', 'r2'] }, { 'S2' => ['b'] }, { 'S1' => ['a'] }])
    end
  end

  context 'when a section was removed without its content' do
    before do
      draft.remove_type_de_champ(stable_id('S2'))
      publish
    end

    it 'lays it at the end, its content staying where the newest revision lays it' do
      expect(layout(aggregate.public_children)).to eq(['intro', { 'rep' => ['r1', 'r2'] }, { 'S1' => ['a', 'b'] }, 'S2'])
    end
  end

  context 'when the child of a repetition was removed' do
    before do
      draft.remove_type_de_champ(stable_id('r1'))
      publish
    end

    it 'keeps it at the end of the repetition' do
      expect(layout(aggregate.public_children).second).to eq({ 'rep' => ['r2', 'r1'] })
    end
  end

  context 'when a type de champ was moved to another section' do
    before do
      draft.move_type_de_champ(stable_id('b'), 3)
      publish
    end

    it 'lays it where the newest revision does, only' do
      expect(layout(aggregate.public_children)).to eq(['intro', { 'rep' => ['r1', 'r2'] }, { 'S1' => ['b', 'a'] }, 'S2'])
    end
  end

  context 'when a type de champ was updated' do
    before do
      draft.find_and_ensure_exclusive_use(stable_id('intro')).update!(libelle: 'intro v2')
      publish
    end

    it 'points at its newest version' do
      expect(aggregate.public_children.first.type_de_champ_id).to eq(procedure.published_revision.public_root_type_de_champs.first.id)
      expect(aggregate.public_children.first.type_de_champ_id).not_to eq(published_revisions.first.public_root_type_de_champs.first.id)
    end
  end

  context 'when an annotation was removed' do
    before do
      draft.remove_type_de_champ(stable_id('annotation'))
      publish
    end

    it 'aggregates each scope on its own' do
      expect(layout(aggregate.private_children)).to eq(['annotation'])
      expect(procedure.published_revision.type_de_champ_tree.private_children).to be_empty
    end
  end

  context 'when a repetition became something else' do
    before do
      draft.find_and_ensure_exclusive_use(stable_id('rep')).update!(type_champ: :text)
      publish
    end

    it 'leaves out what it held' do
      expect(layout(aggregate.public_children)).to eq(['intro', 'rep', { 'S1' => ['a'] }, { 'S2' => ['b'] }])
    end
  end

  context 'when a header section became something else, and its content was removed' do
    before do
      draft.find_and_ensure_exclusive_use(stable_id('S2')).update!(type_champ: :text)
      draft.remove_type_de_champ(stable_id('b'))
      publish
    end

    it 'lays its content at the end of the container it sits in' do
      expect(layout(aggregate.public_children)).to eq(['intro', { 'rep' => ['r1', 'r2'] }, { 'S1' => ['a', 'S2', 'b'] }])
    end
  end

  context 'when a header section was something else for one publication' do
    before do
      draft.find_and_ensure_exclusive_use(stable_id('S2')).update!(type_champ: :text)
      draft.remove_type_de_champ(stable_id('b'))
      publish
      draft.find_and_ensure_exclusive_use(stable_id('S2')).update!(type_champ: :header_section)
      publish
    end

    it 'leaves its former content where that publication laid it' do
      expect(layout(aggregate.public_children)).to eq(['intro', { 'rep' => ['r1', 'r2'] }, { 'S1' => ['a', 'b'] }, 'S2'])
    end
  end

  context 'over several publications' do
    before do
      draft.remove_type_de_champ(stable_id('a'))
      draft.add_type_de_champ(type_champ: :text, libelle: 'c', after_stable_id: stable_id('S1'))
      publish
      draft.remove_type_de_champ(stable_id('r2'))
      draft.remove_type_de_champ(stable_id('c'))
      draft.move_type_de_champ(stable_id('intro'), 3)
      publish
    end

    it 'lays the latest removed first' do
      expect(layout(aggregate.public_children)).to eq([{ 'rep' => ['r1', 'r2'] }, { 'S1' => ['c', 'a'] }, { 'S2' => ['intro', 'b'] }])
    end

    it 'can be carried over from a publication to the next' do
      trees = published_revisions.map(&:type_de_champ_tree)
      carried_over = trees.reduce(described_class.new) { |aggregate, tree| described_class.aggregate([aggregate, tree]) }

      expect(carried_over).to eq(aggregate)
    end
  end
end
