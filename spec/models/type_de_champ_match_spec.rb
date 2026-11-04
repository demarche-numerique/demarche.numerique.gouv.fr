# frozen_string_literal: true

require 'rails_helper'

describe TypeDeChampMatch do
  empty_seeds ProcedureUserOverlap

  let(:pair) { [procedures.individual, procedures.close].sort_by(&:id) }
  let(:overlap) do
    ProcedureUserOverlap.create!(left_procedure: pair.first, right_procedure: pair.last,
                                 common_users_count: 500)
  end

  def match(matching_users_count, common_users_count, stable_id: matching_users_count)
    described_class.create!(left_procedure_id: overlap.left_procedure_id, left_stable_id: stable_id,
                            right_procedure_id: overlap.right_procedure_id, right_stable_id: stable_id + 1_000,
                            matching_users_count:, common_users_count:)
  end

  describe '#score' do
    it 'discounts a perfect concordance observed on almost nobody' do
      expect(match(2, 2).score).to be_within(0.001).of(0.342)
      expect(match(500, 500).score).to be_within(0.001).of(0.992)
    end

    it 'ranks a thin perfect concordance above a large mediocre one' do
      expect(match(19, 19).score).to be > match(25, 50).score
    end

    it 'is zero when nobody answered both champs' do
      expect(described_class.new(matching_users_count: 0, common_users_count: 0).score).to eq(0.0)
    end
  end

  # La formule est écrite deux fois, en Ruby pour un enregistrement et en SQL
  # pour les scopes. Si les deux divergent, un scope et un prédicat se
  # contredisent sans que rien ne le signale.
  it 'computes the same score in SQL as in Ruby' do
    [[2, 2], [19, 19], [25, 50], [1, 2], [447, 500], [500, 500]].each_with_index do |(k, n), index|
      match(k, n, stable_id: index + 1)
    end

    in_sql = described_class.pluck(:id, Arel.sql(described_class::SCORE_SQL)).to_h

    described_class.find_each do |record|
      expect(record.score).to be_within(1e-9).of(in_sql.fetch(record.id))
    end
  end

  describe '#confirmed?' do
    it 'keeps what the score supports and drops the rest' do
      expect([match(500, 500, stable_id: 1), match(19, 19, stable_id: 2)]).to all(be_confirmed)
      expect([match(25, 50, stable_id: 3), match(2, 2, stable_id: 4)]).to all(satisfy { !it.confirmed? })
    end
  end

  describe '.by_score' do
    it 'puts the best supported couple first' do
      match(2, 2, stable_id: 1)
      match(500, 500, stable_id: 2)
      match(19, 19, stable_id: 3)

      expect(described_class.by_score.pluck(:matching_users_count)).to eq([500, 19, 2])
    end
  end
end
