# frozen_string_literal: true

module Maintenance
  class T20260504BackfillCanonicalKeysInDepartementChampsTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    RANGE_SIZE = 50_000

    def collection
      min_id = ChampData.minimum(:id) || 0
      max_id = ChampData.maximum(:id) || 0
      (min_id..max_id).step(RANGE_SIZE).map { |from| from...(from + RANGE_SIZE) }
    end

    def process(range)
      Champs::DepartementChamp.where(id: range).update_all(<<~SQL.squish)
        value_json = COALESCE(value_json, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
          'department_code', external_id,
          'region_code',     value_json->>'code_region'
        ))
      SQL
    end

    def count
      collection.size
    end
  end
end
