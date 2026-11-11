# frozen_string_literal: true

describe TypeDeChampTree, '.legacy_export_order' do
  let(:procedure) do
    create(:procedure, :published, public_type_de_champs: [
      { type: :text, libelle: 'a' },
      { type: :header_section, level: 1, libelle: 'S1' },
      { type: :text, libelle: 'b' },
      { type: :repetition, libelle: 'rep', children: [{ libelle: 'r1' }, { libelle: 'r2' }, { libelle: 'r3' }] },
      { type: :text, libelle: 'c' },
    ], private_type_de_champs: [{ libelle: 'annotation' }])
  end
  let(:administrateur) { procedure.administrateurs.first }
  let(:order) { described_class.legacy_export_order(procedure.published_revisions_oldest_first.map(&:type_de_champ_tree)) }

  def stable_id(libelle) = TypeDeChamp.where(id: procedure.revisions.joins(:revision_type_de_champs).select(:type_de_champ_id)).find_by!(libelle:).stable_id
  def libelles(stable_ids) = stable_ids.map { |stable_id| TypeDeChamp.where(stable_id:).order(:id).first.libelle }
  def draft = procedure.draft_revision
  def publish = procedure.publish_revision!(administrateur).then { procedure.reload }

  it 'follows the coordinates: header sections hold nothing, the private ones come last' do
    expect(libelles(order.fetch(nil))).to eq(['a', 'S1', 'b', 'rep', 'c', 'annotation'])
    expect(libelles(order.fetch(stable_id('rep')))).to eq(['r1', 'r2', 'r3'])
  end

  context 'when a type de champ was removed' do
    before do
      draft.remove_type_de_champ(stable_id('b'))
      draft.remove_type_de_champ(stable_id('r1'))
      publish
    end

    it 'keeps its last position, after the type de champ holding it now' do
      expect(libelles(order.fetch(nil))).to eq(['a', 'S1', 'rep', 'b', 'c', 'annotation'])
      expect(libelles(order.fetch(stable_id('rep')))).to eq(['r2', 'r1', 'r3'])
    end
  end

  context 'when a type de champ was moved' do
    before do
      draft.move_type_de_champ(stable_id('c'), 0)
      publish
    end

    it 'takes its position in the newest revision' do
      expect(libelles(order.fetch(nil))).to eq(['c', 'a', 'S1', 'b', 'rep', 'annotation'])
    end
  end
end
