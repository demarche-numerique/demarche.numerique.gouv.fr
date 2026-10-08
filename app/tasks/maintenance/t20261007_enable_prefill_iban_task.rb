# frozen_string_literal: true

module Maintenance
  class T20261007EnablePrefillIbanTask < MaintenanceTasks::Task
    # Documentation: cette tâche active le flag prefill_iban sur les démarches
    # dont au moins un champ IBAN a été prérempli, pour qu'elles gardent le
    # préremplissage IBAN désormais retiré des autres. Elle tourne au déploiement
    # pour que les autres instances n'aient rien à faire. Si une intégration
    # a échappé à la détection, il suffit de réactiver le flag sur sa démarche
    # (manager ou Flipper.enable(:prefill_iban, procedure)), ici comme ailleurs.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    run_on_first_deploy

    SLICE_SIZE = 50
    SLICE_TIMEOUT = '5min'

    def collection
      Procedure.with_discarded.where(id: prefilled_procedure_ids)
    end

    def process(procedure)
      Flipper.enable(:prefill_iban, procedure)
    end

    private

    # champs.prefilled has no index: stable_id slices bound each query.
    # Dossier.prefilled leaves out the IBANs written by a referentiel, which flag the champ too.
    def prefilled_procedure_ids
      iban_stable_ids.each_slice(SLICE_SIZE).flat_map do |slice|
        with_statement_timeout(SLICE_TIMEOUT) do
          Champs::IbanChamp.prefilled
            .where(stable_id: slice)
            .joins(dossier: :revision)
            .merge(Dossier.prefilled)
            .distinct
            .pluck('procedure_revisions.procedure_id')
        end
      end.uniq
    end

    def iban_stable_ids
      TypesDeChamp::IbanTypeDeChamp.distinct.pluck(:stable_id).compact
    end
  end
end
