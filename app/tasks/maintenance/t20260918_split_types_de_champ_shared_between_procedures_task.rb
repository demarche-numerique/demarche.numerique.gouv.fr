# frozen_string_literal: true

module Maintenance
  class T20260918SplitTypesDeChampSharedBetweenProceduresTask < MaintenanceTasks::Task
    # Documentation: quelques démarches clonées (pour l’essentiel les 11 et 12
    # mai 2023) partagent les types de champ de la démarche d’origine au lieu
    # d’en avoir une copie. Cette tâche donne à la plus récente des deux ses
    # propres types de champ, pour qu’un type de champ n’appartienne plus qu’à
    # une seule démarche.

    # Deliberately manual: it walks every procedure, and must not fire on a deploy.
    # Procedures rather than the shared types de champ: finding those is a scan
    # of every coordinate, which would run again with each batch.
    def collection
      Procedure.with_discarded
    end

    # The oldest procedure keeps the type de champ. Each other one gets a single
    # copy for all its revisions, so that a type de champ left untouched between
    # two revisions stays the same record.
    def process(procedure)
      type_de_champ_ids_held_by_an_older_procedure(procedure).each do |type_de_champ_id|
        TypeDeChamp.transaction do
          type_de_champ = TypeDeChamp.find(type_de_champ_id)
          cloned_type_de_champ = type_de_champ.deep_clone do |original, kopy|
            ClonePiecesJustificativesService.clone_attachments(original, kopy)
          end
          # a faithful copy: types de champ of 2020 need not pass today's
          # validations, whose callbacks would also rewrite the attributes
          cloned_type_de_champ.save!(validate: false)

          coordinates(procedure).where(type_de_champ_id:).update_all(type_de_champ_id: cloned_type_de_champ.id)
        end
      end
    end

    private

    def coordinates(procedure)
      ProcedureRevisionTypeDeChamp
        .unscope(:eager_load)
        .where(revision_id: ProcedureRevision.where(procedure_id: procedure.id).select(:id))
    end

    def type_de_champ_ids_held_by_an_older_procedure(procedure)
      older_coordinates = ProcedureRevisionTypeDeChamp
        .unscope(:eager_load)
        .from("procedure_revision_types_de_champ older_coordinates")
        .joins("INNER JOIN procedure_revisions older_revisions ON older_revisions.id = older_coordinates.revision_id")
        .where("older_coordinates.type_de_champ_id = procedure_revision_types_de_champ.type_de_champ_id")
        .where(older_revisions: { procedure_id: ...procedure.id })

      coordinates(procedure)
        .where("EXISTS (#{older_coordinates.select('1').to_sql})")
        .distinct
        .pluck(:type_de_champ_id)
    end
  end
end
