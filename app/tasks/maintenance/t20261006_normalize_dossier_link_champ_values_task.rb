# frozen_string_literal: true

module Maintenance
  class T20261006NormalizeDossierLinkChampValuesTask < MaintenanceTasks::Task
    # A dossier link champ could hold "n° 12345" before its format validation (#14163): keep the
    # number when it is the only one, and date the dossier so updatedSince exposes the clean value.

    include StatementsHelpersConcern

    SINGLE_NUMBER = '^[^0-9]*0*([1-9][0-9]*)[^0-9]*$'

    def collection
      TypeDeChamp.where(type_champ: :dossier_link).distinct.pluck(:stable_id)
    end

    def process(stable_id)
      with_statement_timeout("5min") do
        rows = ChampData.where(stable_id:, stream: Dossier::MAIN_STREAM)
          .where("value !~ '^[0-9]+$' AND value ~ ?", SINGLE_NUMBER)
          .pluck(:id, :dossier_id, :type)
          # Not in SQL: a type condition sends the planner through the whole type index.
          .filter { it.third == Champs::DossierLinkChamp.name }
        next if rows.empty?

        ChampData.where(id: rows.map(&:first)).update_all(["value = substring(value from ?)", SINGLE_NUMBER])
        Dossier.where(id: rows.map(&:second).uniq).update_all(updated_at: Time.current)
      end
    end
  end
end
