# frozen_string_literal: true

describe AggregatedRevision do
  subject(:aggregate) { procedure.aggregated_revision }

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

  def stable_ids(types_de_champ) = types_de_champ.map(&:stable_id)

  describe 'with a single published revision' do
    it 'mirrors the published revision' do
      expect(stable_ids(aggregate.public_types_de_champ)).to eq([110, 120, 130, 140])
      expect(stable_ids(aggregate.children_of(aggregate.type_de_champ(130)))).to eq([131])
      expect(stable_ids(aggregate.children_of(aggregate.type_de_champ(120)))).to eq([121, 122])
      expect(stable_ids(aggregate.flat_public_types_de_champ)).to eq([110, 120, 121, 122, 130, 131, 140, 141])
    end
  end

  describe 'with a never-published procedure' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text, libelle: 'draft only', stable_id: 210 }]) }

    it 'aggregates the draft alone' do
      expect(stable_ids(aggregate.public_types_de_champ)).to eq([210])
    end
  end

  describe 'when a champ was removed from its section' do
    before do
      procedure.draft_revision.remove_type_de_champ(131)
      procedure.publish_revision!(administrateur)
    end

    it 'keeps the removed champ at the end of its last-known section' do
      expect(procedure.published_revision.type_de_champ(131)).to be_nil
      expect(stable_ids(aggregate.children_of(aggregate.type_de_champ(130)))).to eq([131])
      expect(aggregate.type_de_champ(131).section.stable_id).to eq(130)
    end

    it 'appends the removed champ after the section content of the newest revision' do
      procedure.draft_revision.add_type_de_champ(
        type_champ: :text, libelle: 'c', after_stable_id: 130
      )
      procedure.publish_revision!(administrateur)
      new_stable_id = procedure.published_revision.children_of(procedure.published_revision.type_de_champ(130)).first.stable_id

      expect(stable_ids(procedure.aggregated_revision.children_of(procedure.aggregated_revision.type_de_champ(130)))).to eq([new_stable_id, 131])
    end
  end

  describe 'when a section was removed with its content' do
    before do
      procedure.draft_revision.remove_type_de_champ(140)
      procedure.draft_revision.remove_type_de_champ(141)
      procedure.publish_revision!(administrateur)
    end

    it 'appends the removed section at the end, with its removed content' do
      expect(stable_ids(aggregate.public_types_de_champ)).to eq([110, 120, 130, 140])
      expect(stable_ids(aggregate.children_of(aggregate.type_de_champ(140)))).to eq([141])
      expect(aggregate.type_de_champ(141).section.stable_id).to eq(140)
    end
  end

  describe 'when a repetition child was removed' do
    before do
      procedure.draft_revision.remove_type_de_champ(122)
      procedure.publish_revision!(administrateur)
    end

    it 'keeps the removed child at the end of the repetition' do
      expect(stable_ids(aggregate.children_of(aggregate.type_de_champ(120)))).to eq([121, 122])
      expect(aggregate.type_de_champ(122).repetition.stable_id).to eq(120)
    end
  end

  describe 'when a champ was moved to another section' do
    before do
      # move b (position 5) right after S1 (position 2): S1 now holds [b, a]
      procedure.draft_revision.move_type_de_champ(141, 3)
      procedure.publish_revision!(administrateur)
    end

    it 'places the champ in its newest section only' do
      expect(stable_ids(aggregate.children_of(aggregate.type_de_champ(130)))).to eq([141, 131])
      expect(stable_ids(aggregate.children_of(aggregate.type_de_champ(140)))).to eq([])
      expect(aggregate.type_de_champ(141).section.stable_id).to eq(130)
    end

    it 'navigates the same type de champ against any provider' do
      oldest_revision = procedure.revisions.min_by(&:created_at)

      expect(aggregate.type_de_champ(141).section.stable_id).to eq(130)
      expect(procedure.published_revision.type_de_champ(141).section.stable_id).to eq(130)
      expect(oldest_revision.type_de_champ(141).section.stable_id).to eq(140)
    end
  end

  describe 'when a champ was updated' do
    before do
      procedure.draft_revision.find_and_ensure_exclusive_use(110).update!(libelle: 'intro v2')
      procedure.publish_revision!(administrateur)
    end

    it 'serves the newest version of the type de champ' do
      expect(aggregate.type_de_champ(110).libelle).to eq('intro v2')
    end
  end

  describe 'caching' do
    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    it 'reuses the cached merge without walking the revisions again' do
      expect(stable_ids(AggregatedRevision.new(procedure).public_types_de_champ)).to eq([110, 120, 130, 140])

      expect(procedure).not_to receive(:revisions)
      expect(stable_ids(AggregatedRevision.new(procedure).public_types_de_champ)).to eq([110, 120, 130, 140])
    end

    it 'turns over when a new revision is published' do
      expect(AggregatedRevision.new(procedure).type_de_champ(110).libelle).to eq('intro')

      procedure.draft_revision.find_and_ensure_exclusive_use(110).update!(libelle: 'intro v2')
      procedure.publish_revision!(administrateur)

      expect(AggregatedRevision.new(procedure.reload).type_de_champ(110).libelle).to eq('intro v2')
    end

    it 'does not cache a procedure en brouillon' do
      brouillon = create(:procedure, types_de_champ_public: [{ type: :text, libelle: 'draft', stable_id: 410 }])

      expect(Rails.cache).not_to receive(:fetch)
      expect(stable_ids(AggregatedRevision.new(brouillon).public_types_de_champ)).to eq([410])
    end
  end

  describe 'private types de champ' do
    let(:procedure) do
      create(:procedure, :published,
        types_de_champ_public: [{ type: :text, libelle: 'public', stable_id: 310 }],
        types_de_champ_private: [{ type: :text, libelle: 'annotation', stable_id: 320 }])
    end

    it 'aggregates each scope separately' do
      expect(stable_ids(aggregate.public_types_de_champ)).to eq([310])
      expect(stable_ids(aggregate.private_types_de_champ)).to eq([320])
      expect(aggregate.type_de_champ(320, :private).libelle).to eq('annotation')
      expect(aggregate.type_de_champ(320, :public)).to be_nil
    end
  end
end
