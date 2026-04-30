# frozen_string_literal: true

module Maintenance
  class T20260408lowercaseTypeDeChampNatureValuesTask < MaintenanceTasks::Task
    # Normalise les valeurs de la colonne `nature` des types de champ
    # en lowercase (ex: 'TITRE_IDENTITE' → 'titre_identite', 'RIB' → 'rib').

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    run_on_first_deploy

    def collection
      TypeDeChamp.where.not(nature: nil).in_batches
    end

    def process(batch)
      batch.update_all(Arel.sql("nature = LOWER(nature)"))
    end
  end
end
