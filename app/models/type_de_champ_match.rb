# frozen_string_literal: true

class TypeDeChampMatch < ApplicationRecord
  WILSON_Z = 1.96
  MIN_SCORE = ENV.fetch('CHAMP_MATCHING_MIN_SCORE') { 0.5 }.to_f

  # The same lower bound as #score, so a scope and a record never disagree.
  SCORE_SQL = begin
    z2 = WILSON_Z**2
    n = 'NULLIF(common_users_count, 0)::float'
    p = "(matching_users_count::float / #{n})"

    "((#{p} + #{z2} / (2 * #{n}) - #{WILSON_Z} * sqrt(#{p} * (1 - #{p}) / #{n} + #{z2} / (4 * #{n} * #{n}))) / (1 + #{z2} / #{n}))"
  end.freeze

  belongs_to :procedure_user_overlap,
             primary_key: [:left_procedure_id, :right_procedure_id],
             foreign_key: [:left_procedure_id, :right_procedure_id],
             inverse_of: :type_de_champ_matches

  scope :by_score, -> { order(Arel.sql("#{SCORE_SQL} DESC")) }

  # Lower bound of the Wilson interval: the most pessimistic ratio the
  # observation supports. It separates a 2/2 from a 500/500, which the ratio
  # alone reads as the same 1.0.
  def score
    return 0.0 if common_users_count.zero?

    ratio = matching_users_count.fdiv(common_users_count)
    z2 = WILSON_Z**2
    centre = ratio + z2 / (2.0 * common_users_count)
    margin = WILSON_Z * Math.sqrt(ratio * (1 - ratio) / common_users_count + z2 / (4.0 * common_users_count**2))

    (centre - margin) / (1 + z2 / common_users_count)
  end

  def confirmed? = score >= MIN_SCORE
end
