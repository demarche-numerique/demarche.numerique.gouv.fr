# frozen_string_literal: true

module Maintenance
  class T20260728BackfillSearchTermsTsvectorTask < MaintenanceTasks::Task
    # Backfill the stored tsvector columns added by
    # AddSearchTermsTsvectorToDossiers.
    #
    # The search reads only these columns: dossiers not reindexed since they
    # were added stay unfindable until this completes.

    include RunnableOnDeployConcern

    run_on_first_deploy

    def collection
      Dossier.where(search_terms_tsvector: nil)
    end

    def process(dossier)
      dossier.index_search_terms
    end
  end
end
