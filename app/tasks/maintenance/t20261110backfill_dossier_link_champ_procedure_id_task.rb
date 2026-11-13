# frozen_string_literal: true

module Maintenance
  class T20261110backfillDossierLinkChampProcedureIdTask < MaintenanceTasks::Task
    RANGE_SIZE = 1_000_000
    SLICE_SIZE = 1_000

    def collection
      (0..ChampData.maximum(:id).to_i).step(RANGE_SIZE).to_a
    end

    def process(from)
      Champs::DossierLinkChamp
        .where(id: from...(from + RANGE_SIZE))
        .where.not(value: [nil, ''])
        .pluck(:id, :value, :value_json)
        .filter { |_id, value| value.match?(Champs::DossierLinkChamp::DOSSIER_NUMBER_REGEXP) }
        .each_slice(SLICE_SIZE) { backfill(it) }
    end

    private

    def backfill(rows)
      value_jsons = Champs::DossierLinkChamp.linked_value_jsons(rows.map { |_id, value| value.to_i }.uniq)

      rows
        .reject { |_id, value, stored| stored == value_jsons[value.to_i] }
        .group_by { |_id, value| value_jsons[value.to_i] }
        .except(nil)
        .each do |value_json, group|
          Champs::DossierLinkChamp
            .where(id: group.map(&:first), value: group.map(&:second).uniq)
            .update_all(value_json:)
        end
    end
  end
end
