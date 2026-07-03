# frozen_string_literal: true

module Maintenance
  class T20251031backfillMissingEtablissementTask < MaintenanceTasks::Task
    # Cette tâche permet de re-fetch les établissements manquants

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    csv_collection

    def process(row)
      champ_data = ChampData.where(type: "Champs::SiretChamp").find_by(id: row["champ_id"].to_i)

      return if champ_data.nil?
      return if champ_data.external_id.nil?

      champ = Champ.from_data(champ_data)
      return if champ.nil?

      champ.reset_external_data!
      if champ.may_fetch_later?
        champ.fetch_later!(wait: rand(0..max_wait))
      end
    end

    # we spread the fethes every 10 seconds per champ
    def max_wait
      count * 10
    end
  end
end
