# frozen_string_literal: true

describe RepetitionRow do
  let(:procedure) do
    create(:procedure, :published, public_type_de_champs: [
      {
        type: :repetition,
        libelle: 'Bloc',
        children: [{ type: :text, libelle: 'Nom' }, { type: :text, libelle: 'Prénom' }],
      },
    ])
  end
  let(:dossier) { create(:dossier, procedure:) }
  let(:fresh_dossier) { Dossier.find(dossier.id) }

  # the repetition starts with one row
  before { 3.times { dossier.public_root_champs.find(&:repetition?).add_row(updated_by: 'test') } }

  describe '#flat_children' do
    it 'computes the revision children once for the whole repetition' do
      revision = fresh_dossier.revision
      calls = 0
      allow(revision).to receive(:children_of).and_wrap_original do |original, *args|
        calls += 1
        original.call(*args)
      end

      expect(fresh_dossier.public_flat_champs.size).to eq(9) # the repetition + 4 rows x 2 children
      expect(calls).to eq(1)
    end
  end
end
