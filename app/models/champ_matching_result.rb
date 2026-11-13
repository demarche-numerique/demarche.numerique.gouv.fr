# frozen_string_literal: true

class ChampMatchingResult
  include ActiveModel::Model

  Section = Data.define(:procedure_id, :libelle, :partners) do
    def couples_count = partners.sum { it.couples.size }
    def confirmed_count = partners.sum { |partner| partner.couples.count(&:confirmed) }
  end

  Partner = Data.define(:procedure_id, :libelle, :common_users_count, :couples)

  Value = Data.define(:raw, :comparable, :dossier_id)

  # What one usager answered on both champs of the couple, most recent dossier first.
  Observation = Data.define(:namespace, :values, :partner_namespace, :partner_values) do
    def answered? = values.any? && partner_values.any? && namespace == partner_namespace
    def matching? = answered? && shared_comparables.any?
    def shared_comparables = answered? ? comparables & partner_comparables : []
    def comparables = values.map(&:comparable).uniq
    def partner_comparables = partner_values.map(&:comparable).uniq
  end

  attr_accessor :id,
                :procedure_id, :stable_id, :libelle,
                :partner_procedure_id, :partner_stable_id, :partner_libelle,
                :common_users_count, :matching_users_count, :score, :confirmed, :namespace, :min_score

  def persisted? = true

  # The procedure the row was read from rides along, so the page it opens keeps
  # that procedure on the left.
  def to_param = "#{id}-#{procedure_id}"

  # Replays, for this couple only and on today's data, the selection the
  # matching makes: the same usagers, the same capped dossiers, the same
  # namespace rule. The spec holds it to the counts the matching stored.
  def observations
    common_user_ids.each_slice(ChampMatchingConcern::USERS_PER_SLICE).flat_map do |user_ids|
      rows_by_user = dossier_rows_by_user(user_ids)
      values = values_by_dossier(rows_by_user.values.flatten(1).map(&:second))

      user_ids.map do |user_id|
        namespace, observed = couple_side(rows_by_user.fetch(user_id), values, procedure_id, stable_id)
        partner_namespace, partner_observed = couple_side(rows_by_user.fetch(user_id), values, partner_procedure_id, partner_stable_id)

        Observation.new(namespace:, values: observed, partner_namespace:, partner_values: partner_observed)
      end
    end
  end

  class << self
    def find(param)
      id, procedure_id = param.to_s.split('-').map(&:to_i)
      match = TypeDeChampMatch.find(id)

      oriented(match, procedure_id == match.right_procedure_id ? :right : :left, champs_of([match]))
    end

    # One section per procedure, so a match appears under each of its two
    # procedures. Grouping keeps the order it reads, so the best score of a
    # couple carries its partner, and the best partner carries its procedure.
    def sections
      matches = TypeDeChampMatch.by_score.to_a
      return [] if matches.empty?

      procedure_ids = matches.flat_map { [it.left_procedure_id, it.right_procedure_id] }
      champs = champs_of(matches)
      procedures = Procedure.with_discarded.where(id: procedure_ids).pluck(:id, :libelle).to_h
      pairs = ProcedureUserOverlap.within(procedure_ids).pluck(:left_procedure_id, :right_procedure_id, :common_users_count)
        .to_h { |left_procedure_id, right_procedure_id, count| [[left_procedure_id, right_procedure_id], count] }

      matches
        .flat_map { [oriented(it, :left, champs), oriented(it, :right, champs)] }
        .group_by(&:procedure_id)
        .map { |procedure_id, rows| Section.new(procedure_id:, libelle: procedures[procedure_id], partners: partners_of(rows, procedures, pairs)) }
    end

    private

    def partners_of(rows, procedures, pairs)
      rows.group_by(&:partner_procedure_id).map do |partner_procedure_id, couples|
        Partner.new(
          procedure_id: partner_procedure_id,
          libelle: procedures[partner_procedure_id],
          common_users_count: pairs[[couples.first.procedure_id, partner_procedure_id].minmax],
          couples:
        )
      end
    end

    def oriented(match, side, champs)
      procedure_id, stable_id, partner_procedure_id, partner_stable_id =
        if side == :left
          [match.left_procedure_id, match.left_stable_id, match.right_procedure_id, match.right_stable_id]
        else
          [match.right_procedure_id, match.right_stable_id, match.left_procedure_id, match.left_stable_id]
        end
      namespace = ChampMatching::ComparableValue::COMPARISON_NAMESPACES[champs.dig([procedure_id, stable_id], :type_champ)]

      new(
        id: match.id,
        procedure_id:,
        stable_id:,
        libelle: champs.dig([procedure_id, stable_id], :libelle),
        partner_procedure_id:,
        partner_stable_id:,
        partner_libelle: champs.dig([partner_procedure_id, partner_stable_id], :libelle),
        common_users_count: match.common_users_count,
        matching_users_count: match.matching_users_count,
        score: match.score,
        confirmed: match.confirmed?(namespace),
        namespace:,
        min_score: TypeDeChampMatch.min_score(namespace)
      )
    end

    # Ordered by revision, so the last libellé and type a champ was given win.
    def champs_of(matches)
      ProcedureRevisionTypeDeChamp
        .unscope(:eager_load)
        .joins(:revision, :type_de_champ)
        .where(procedure_revisions: { procedure_id: matches.flat_map { [it.left_procedure_id, it.right_procedure_id] } },
               types_de_champ: { stable_id: matches.flat_map { [it.left_stable_id, it.right_stable_id] } })
        .order('procedure_revisions.id')
        .pluck('procedure_revisions.procedure_id', 'types_de_champ.stable_id', 'types_de_champ.libelle', 'types_de_champ.type_champ')
        .to_h { |procedure_id, stable_id, libelle, type_champ| [[procedure_id, stable_id], { libelle:, type_champ: }] }
    end
  end

  private

  def dossiers
    ProcedureUserOverlap.eligible_dossiers.where(procedure_revisions: { procedure_id: [procedure_id, partner_procedure_id] })
  end

  def common_user_ids
    dossiers
      .group(:user_id)
      .having("COUNT(DISTINCT #{ChampMatchingConcern::PROCEDURE_ID}) = 2")
      .order(Arel.sql('MAX(dossiers.depose_at) DESC, dossiers.user_id DESC'))
      .limit(ChampMatchingConcern::MAX_USERS)
      .pluck(:user_id)
  end

  def dossier_rows_by_user(user_ids)
    dossiers
      .where(user_id: user_ids)
      .order_by_depose_at
      .pluck(:user_id, :id, ChampMatchingConcern::PROCEDURE_ID)
      .group_by(&:first)
      .transform_values do |user_rows|
        user_rows
          .group_by { |_user_id, _dossier_id, row_procedure_id| row_procedure_id }
          .flat_map { |_procedure_id, rows| rows.first(ChampMatchingConcern::MAX_DOSSIERS_PER_USER_AND_PROCEDURE) }
      end
  end

  def values_by_dossier(dossier_ids)
    ChampData
      .where(dossier_id: dossier_ids, stream: Dossier::MAIN_STREAM, private: false, row_id: nil,
             stable_id: [stable_id, partner_stable_id], type: ChampMatching::ComparableValue::CHAMP_TYPES.keys)
      .pluck(:dossier_id, :stable_id, :type, :value, ChampMatchingConcern::ADDRESS_VALUE_JSON, :external_id)
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(dossier_id, row_stable_id, type, value, value_json, external_id), acc|
        namespace = ChampMatching::ComparableValue::CHAMP_TYPES.fetch(type)
        comparable = ChampMatching::ComparableValue.call(namespace:, value:, value_json:, external_id:)
        acc[dossier_id] << [namespace, row_stable_id, comparable, value] if comparable.present?
      end
  end

  # The most recent dossier fixes the namespace, as in the matching.
  def couple_side(user_rows, values, side_procedure_id, side_stable_id)
    namespace = nil
    observed = []

    user_rows.each do |_user_id, dossier_id, row_procedure_id|
      next if row_procedure_id != side_procedure_id

      values.fetch(dossier_id, []).each do |row_namespace, row_stable_id, comparable, raw|
        next if row_stable_id != side_stable_id

        namespace ||= row_namespace
        observed << Value.new(raw:, comparable:, dossier_id:) if row_namespace == namespace
      end
    end

    [namespace, observed]
  end
end
