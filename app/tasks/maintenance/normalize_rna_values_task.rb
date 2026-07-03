# frozen_string_literal: true

module Maintenance
  class NormalizeRNAValuesTask < MaintenanceTasks::Task
    def collection
      ChampData.where(type: "Champs::RNAChamp").where.not(value: nil)
    end

    def process(element)
      if /\s/.match?(element.value)
        element.update_column(:value, element.value.gsub(/\s+/, ''))
      end
    end

    def count
      # to costly
    end
  end
end
