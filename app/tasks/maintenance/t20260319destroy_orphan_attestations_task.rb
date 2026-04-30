# frozen_string_literal: true

module Maintenance
  class T20260319destroyOrphanAttestationsTask < MaintenanceTasks::Task
    # Documentation: cette tâche supprime les attestations orphelines
    # attachées à des dossiers classés sans suite, créées par une race condition
    # entre l'acceptation et le classement sans suite.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    def collection
      Attestation.joins(:dossier).where(dossiers: { state: :sans_suite })
    end

    def process(attestation)
      attestation.destroy!
    end

    def count
      collection.count
    end
  end
end
