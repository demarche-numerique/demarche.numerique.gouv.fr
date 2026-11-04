# frozen_string_literal: true

module ChampMatchingConcern
  extend ActiveSupport::Concern

  USERS_FLOOR = ENV.fetch('CHAMP_MATCHING_USERS_FLOOR') { 50 }.to_i
  MAX_USERS = ENV.fetch('CHAMP_MATCHING_MAX_USERS') { 500 }.to_i
  MAX_DOSSIERS_PER_USER_AND_PROCEDURE = ENV.fetch('CHAMP_MATCHING_MAX_DOSSIERS_PER_USER_AND_PROCEDURE') { 5 }.to_i
  USERS_PER_SLICE = 100
  PROCEDURE_ID = 'procedure_revisions.procedure_id'
  # Only an address reads its value_json: the referentiels store a whole
  # payload there that nothing compares.
  ADDRESS_VALUE_JSON = Arel.sql("CASE WHEN champs.type = 'Champs::AddressChamp' THEN champs.value_json END")

  class_methods do
    # Rewrites the pairs of the perimeter and their denominators, in absolute,
    # so running it again neither doubles anything nor leaves a pair that no
    # longer qualifies.
    def refresh_within(procedure_ids)
      rows = pair_counts(procedure_ids)
        .filter { |_pair, count| count >= USERS_FLOOR }
        .map do |(left_procedure_id, right_procedure_id), common_users_count|
          { left_procedure_id:, right_procedure_id:, common_users_count: }
        end

      transaction do
        TypeDeChampMatch.within(procedure_ids).delete_all
        within(procedure_ids).delete_all
        insert_all!(rows) if rows.any?
      end
    end

    def eligible_dossiers
      Dossier
        .joins(:revision)
        .where.not(depose_at: nil)
        .where.not(user_id: nil)
        .where(for_tiers: false)
    end

    private

    def pair_counts(procedure_ids)
      open_ids = Procedure.publiees.where(id: procedure_ids).ids.to_set
      return {} if open_ids.empty?

      counts = Hash.new(0)

      eligible_dossiers
        .where(procedure_revisions: { procedure_id: procedure_ids })
        .distinct
        .pluck(:user_id, PROCEDURE_ID)
        .group_by(&:first)
        .each_value do |rows|
          rows.map(&:last).sort.combination(2) do |pair|
            counts[pair] += 1 if pair.any? { open_ids.include?(it) }
          end
        end

      counts
    end
  end

  def refresh_champ_matches!
    matching = Hash.new(0)
    answering = Hash.new(0)

    if shared_champ_types.any?
      common_user_ids.each_slice(USERS_PER_SLICE) do |user_ids|
        accumulate_slice(user_ids, matching, answering)
      end
    end

    rows = matching.filter_map do |couple, count|
      next if count < USERS_FLOOR

      left_stable_id, right_stable_id = couple
      {
        left_procedure_id:, left_stable_id:, right_procedure_id:, right_stable_id:,
        matching_users_count: count, common_users_count: answering.fetch(couple),
      }
    end

    transaction do
      type_de_champ_matches.delete_all
      TypeDeChampMatch.insert_all!(rows) if rows.any?
      update_column(:champs_computed_at, Time.current)
    end
  end

  private

  def common_user_ids
    dossiers_of(left_procedure_id, right_procedure_id)
      .group(:user_id)
      .having("COUNT(DISTINCT #{PROCEDURE_ID}) = 2")
      .order(Arel.sql('MAX(dossiers.depose_at) DESC, dossiers.user_id DESC'))
      .limit(MAX_USERS)
      .pluck(:user_id)
  end

  def accumulate_slice(user_ids, matching, answering)
    rows_by_user = dossiers_of(left_procedure_id, right_procedure_id)
      .where(user_id: user_ids)
      .order_by_depose_at
      .pluck(:user_id, :id, PROCEDURE_ID)
      .group_by(&:first)
      .transform_values { most_recent_per_procedure(it) }

    values = comparable_values_by_dossier(rows_by_user.values.flatten(1).map(&:second))

    rows_by_user.each_value do |user_rows|
      # stable_id => [namespace, values], for each procedure
      entries = { left_procedure_id => {}, right_procedure_id => {} }

      user_rows.each do |_user_id, dossier_id, procedure_id|
        values.fetch(dossier_id, []).each do |namespace, stable_id, value|
          # A champ whose type changed across revisions carries two namespaces:
          # the most recent dossier decides, or its couple would count twice.
          entry = entries[procedure_id][stable_id] ||= [namespace, []]
          entry.last << value if entry.first == namespace
        end
      end

      accumulate_couples(entries[left_procedure_id], entries[right_procedure_id], matching, answering)
    end
  end

  def most_recent_per_procedure(user_rows)
    user_rows
      .group_by { |_user_id, _dossier_id, procedure_id| procedure_id }
      .flat_map { |_procedure_id, rows| rows.first(MAX_DOSSIERS_PER_USER_AND_PROCEDURE) }
  end

  def accumulate_couples(left_entries, right_entries, matching, answering)
    right_by_namespace = right_entries.group_by { |_stable_id, (namespace, _values)| namespace }

    left_entries.each do |left_stable_id, (namespace, left_values)|
      right_by_namespace.fetch(namespace, []).each do |right_stable_id, (_namespace, right_values)|
        couple = [left_stable_id, right_stable_id]

        answering[couple] += 1
        matching[couple] += 1 if left_values.intersect?(right_values)
      end
    end
  end

  def comparable_values_by_dossier(dossier_ids)
    ChampData
      .where(dossier_id: dossier_ids, stream: Dossier::MAIN_STREAM, private: false, row_id: nil, type: shared_champ_types)
      .pluck(:dossier_id, :stable_id, :type, :value, ADDRESS_VALUE_JSON, :external_id)
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(dossier_id, stable_id, type, value, value_json, external_id), acc|
        namespace = ChampMatching::ComparableValue::CHAMP_TYPES.fetch(type)
        comparable = ChampMatching::ComparableValue.call(namespace:, value:, value_json:, external_id:)
        acc[dossier_id] << [namespace, stable_id, comparable] if comparable.present?
      end
  end

  # Only the champ classes whose comparison namespace exists on both sides: an
  # IBAN facing no IBAN can match nothing, so it is neither read nor normalized.
  def shared_champ_types
    @shared_champ_types ||= begin
      shared = namespaces_of(left_procedure_id) & namespaces_of(right_procedure_id)

      ChampMatching::ComparableValue::CHAMP_TYPES.filter_map { |champ_type, namespace| champ_type if shared.include?(namespace) }
    end
  end

  # Every revision, not just the published one: an old dossier can carry a champ
  # the procedure no longer asks for.
  def namespaces_of(procedure_id)
    ProcedureRevisionTypeDeChamp
      .root
      .public_only
      .joins(:revision)
      .where(procedure_revisions: { procedure_id: }, types_de_champ: { type_champ: ChampMatching::ComparableValue::TYPE_CHAMPS })
      .distinct
      .pluck('types_de_champ.type_champ')
      .map { ChampMatching::ComparableValue::COMPARISON_NAMESPACES.fetch(it) }
      .to_set
  end

  def dossiers_of(*procedure_ids)
    self.class.eligible_dossiers.where(procedure_revisions: { procedure_id: procedure_ids })
  end
end
