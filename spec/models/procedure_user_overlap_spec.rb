# frozen_string_literal: true

require 'rails_helper'

describe ProcedureUserOverlap do
  empty_seeds ProcedureUserOverlap

  let(:pair) { [procedures.individual, procedures.close].sort_by(&:id) }

  def overlap(common_users_count: 500, champs_computed_at: nil, procedures_pair: pair)
    described_class.create!(left_procedure: procedures_pair.first, right_procedure: procedures_pair.last,
                            common_users_count:, champs_computed_at:)
  end

  def match(overlap, matching_users_count: 400, common_users_count: 500)
    TypeDeChampMatch.create!(left_procedure_id: overlap.left_procedure_id, left_stable_id: 1,
                             right_procedure_id: overlap.right_procedure_id, right_stable_id: 2,
                             matching_users_count:, common_users_count:)
  end

  describe 'scopes' do
    it 'queues the pairs whose champs have never been compared' do
      expect(described_class.champs_pending).to contain_exactly(overlap)

      described_class.update_all(champs_computed_at: Time.current)
      expect(described_class.champs_pending).to be_empty
    end
  end

  describe 'deletion' do
    it 'clears the champ matches of the pair it removes' do
      record = overlap
      match(record)

      expect { record.destroy! }.to change(TypeDeChampMatch, :count).from(1).to(0)
    end

    # On a retiré la cascade en base : la clé étrangère refuse plutôt que de
    # suivre, donc oublier de vider les matchs lève au point d'appel.
    it 'is refused by the database when the matches are left behind' do
      record = overlap
      match(record)

      expect { record.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'follows a procedure that is destroyed, matches included' do
      procedures_pair = [create(:procedure), create(:procedure)].sort_by(&:id)
      record = overlap(procedures_pair:)
      match(record)

      expect { procedures_pair.first.destroy! }
        .to change(described_class, :count).from(1).to(0)
        .and change(TypeDeChampMatch, :count).from(1).to(0)
    end
  end
end
