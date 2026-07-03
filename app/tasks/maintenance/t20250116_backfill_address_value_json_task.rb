# frozen_string_literal: true

module Maintenance
  class T20250116BackfillAddressValueJSONTask < MaintenanceTasks::Task
    # task run on 15/01/2025, needed for address columns
    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    run_on_first_deploy

    def collection
      ChampData.where(type: "Champs::AddressChamp").where.not(data: nil)
    end

    def process(champ)
      return if champ.data.nil?

      champ.update!(value_json: champ.data)

    rescue ActiveRecord::RecordNotUnique
      # noop, just a champ without dossier
    end

    def count
    end
  end
end
