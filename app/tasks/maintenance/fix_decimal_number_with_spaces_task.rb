# frozen_string_literal: true

module Maintenance
  class FixDecimalNumberWithSpacesTask < MaintenanceTasks::Task
    # normalise les champs nombres en y supprimant les éventuels espaces
    # 2024-07-01-01 PR #10554

    ANY_SPACES = /[[:space:]]/
    def collection
      ChampData.where(type: "Champs::DecimalNumberChamp").where.not(value: nil)
    end

    def process(element)
      if element.value.present? && ANY_SPACES.match?(element.value)
        element.update_column(:value, element.value.gsub(ANY_SPACES, ''))
      end
    end

    def count
      # not really interested in counting because it raises PG Statement timeout
    end
  end
end
