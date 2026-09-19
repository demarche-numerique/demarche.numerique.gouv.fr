# frozen_string_literal: true

module Maintenance
  class T20260918BackfillTypeDeChampProcedureIdTask < MaintenanceTasks::Task
    # Documentation: cette tâche rattache chaque type de champ à sa démarche
    # (`types_de_champ.procedure_id`), en passant par les révisions qui
    # l’utilisent. Les nouveaux types de champ sont rattachés à leur création.
    # Un type de champ partagé par plusieurs démarches est laissé de côté : lancer
    # d’abord T20260918SplitTypesDeChampSharedBetweenProceduresTask, ou relancer
    # cette tâche après elle.

    # Deliberately manual: it walks every procedure and writes most of the types
    # de champ. It must not fire on a deploy.
    # Procedures rather than types de champ: a quarter of those are laid out by
    # no revision and have no procedure to be found, so they would come back
    # with each batch of a relation picking the rows left to fill.
    def collection
      Procedure.with_discarded
    end

    def process(procedure)
      laid_out = coordinates.where(procedure_revisions: { procedure_id: procedure.id })
      # correlated, as NOT IN would list the coordinates of every other procedure
      laid_out_elsewhere = coordinates
        .where("procedure_revision_types_de_champ.type_de_champ_id = types_de_champ.id")
        .where.not(procedure_revisions: { procedure_id: procedure.id })

      TypeDeChamp
        .where(procedure_id: nil)
        .where(id: laid_out.select(:type_de_champ_id))
        .where("NOT EXISTS (#{laid_out_elsewhere.select('1').to_sql})")
        .update_all(procedure_id: procedure.id)
    end

    private

    def coordinates
      ProcedureRevisionTypeDeChamp.unscope(:eager_load).joins(:revision)
    end
  end
end
