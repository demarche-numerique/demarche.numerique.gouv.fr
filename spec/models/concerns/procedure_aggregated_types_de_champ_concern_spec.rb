# frozen_string_literal: true

describe ProcedureAggregatedTypesDeChampConcern do
  let(:procedure) do
    create(:procedure, :published, types_de_champ_public: [
      { type: :text, libelle: 'intro', stable_id: 110 },
      { type: :repetition, libelle: 'rep', stable_id: 120, children: [{ libelle: 'r1', stable_id: 121 }, { libelle: 'r2', stable_id: 122 }] },
      { type: :header_section, level: 1, libelle: 'S1', stable_id: 130 },
      { type: :text, libelle: 'a', stable_id: 131 },
      { type: :header_section, level: 1, libelle: 'S2', stable_id: 140 },
      { type: :text, libelle: 'b', stable_id: 141 },
    ])
  end
  let(:administrateur) { procedure.administrateurs.first }

  def sids(nodes) = nodes.map(&:stable_id)
  def flat(nodes) = nodes.flat_map { [_1, *_1.flat_children] }
  def public_node(stable_id) = flat(procedure.aggregated_public_type_de_champs).find { _1.stable_id == stable_id }
  def children_of(stable_id) = public_node(stable_id).children

  describe 'with a single published revision' do
    it 'mirrors the published revision' do
      expect(sids(procedure.aggregated_public_type_de_champs)).to eq([110, 120, 130, 140])
      expect(sids(children_of(130))).to eq([131])
      expect(sids(children_of(120))).to eq([121, 122])
      expect(sids(flat(procedure.aggregated_public_type_de_champs))).to eq([110, 120, 121, 122, 130, 131, 140, 141])
    end
  end

  describe 'with a never-published procedure' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text, libelle: 'draft only', stable_id: 210 }]) }

    it 'aggregates the draft alone' do
      expect(sids(procedure.aggregated_public_type_de_champs)).to eq([210])
    end
  end

  describe 'when a champ was removed from its section' do
    before do
      procedure.draft_revision.remove_type_de_champ(131)
      procedure.publish_revision!(administrateur)
      procedure.reload
    end

    it 'keeps the removed champ at the end of its last-known section' do
      expect(procedure.published_revision.type_de_champ(131)).to be_nil
      expect(sids(children_of(130))).to eq([131])
    end

    it 'leaves the published revision tree alone' do
      expect(sids(children_of(130))).to eq([131])
      expect(sids(procedure.published_revision.type_de_champ(130).children)).to eq([])
    end

    it 'appends the removed champ after the section content of the newest revision' do
      procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'c', after_stable_id: 130)
      procedure.publish_revision!(administrateur)
      procedure.reload
      new_stable_id = procedure.published_revision.type_de_champ(130).children.first.stable_id

      expect(sids(children_of(130))).to eq([new_stable_id, 131])
    end
  end

  describe 'when a section was removed with its content' do
    before do
      procedure.draft_revision.remove_type_de_champ(140)
      procedure.draft_revision.remove_type_de_champ(141)
      procedure.publish_revision!(administrateur)
      procedure.reload
    end

    it 'appends the removed section at the end, with its removed content' do
      expect(sids(procedure.aggregated_public_type_de_champs)).to eq([110, 120, 130, 140])
      expect(sids(children_of(140))).to eq([141])
    end
  end

  describe 'when a repetition child was removed' do
    before do
      procedure.draft_revision.remove_type_de_champ(122)
      procedure.publish_revision!(administrateur)
      procedure.reload
    end

    it 'keeps the removed child at the end of the repetition' do
      expect(sids(children_of(120))).to eq([121, 122])
      expect(public_node(122).in_repetition?).to be(true)
      expect(public_node(122).enclosing_repetition.stable_id).to eq(120)
    end
  end

  describe 'when a champ was moved to another section' do
    before do
      # move b (position 5) right after S1 (position 2): S1 now holds [b, a]
      procedure.draft_revision.move_type_de_champ(141, 3)
      procedure.publish_revision!(administrateur)
      procedure.reload
    end

    it 'places the champ in its newest section only' do
      expect(sids(children_of(130))).to eq([141, 131])
      expect(sids(children_of(140))).to eq([])
    end
  end

  describe 'when a champ was updated' do
    before do
      procedure.draft_revision.find_and_ensure_exclusive_use(110).update!(libelle: 'intro v2')
      procedure.publish_revision!(administrateur)
      procedure.reload
    end

    it 'serves the newest version of the type de champ' do
      expect(public_node(110).libelle).to eq('intro v2')
    end
  end

  describe 'private types de champ' do
    let(:procedure) do
      create(:procedure, :published,
        types_de_champ_public: [{ type: :text, libelle: 'public', stable_id: 310 }],
        types_de_champ_private: [{ type: :text, libelle: 'annotation', stable_id: 320 }])
    end

    it 'aggregates each scope separately' do
      expect(sids(procedure.aggregated_public_type_de_champs)).to eq([310])
      expect(sids(procedure.aggregated_private_type_de_champs)).to eq([320])
      expect(procedure.aggregated_private_type_de_champs.first.libelle).to eq('annotation')
    end
  end

  describe 'memoization' do
    it 'turns over when a new revision is published' do
      expect(procedure.aggregated_public_type_de_champs.first.libelle).to eq('intro')

      procedure.draft_revision.find_and_ensure_exclusive_use(110).update!(libelle: 'intro v2')
      procedure.publish_revision!(administrateur)

      expect(procedure.aggregated_public_type_de_champs.first.libelle).to eq('intro v2')
    end
  end
end
