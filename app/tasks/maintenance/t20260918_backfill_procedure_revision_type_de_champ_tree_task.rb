# frozen_string_literal: true

module Maintenance
  class T20260918BackfillProcedureRevisionTypeDeChampTreeTask < MaintenanceTasks::Task
    # Documentation: cette tâche calcule et enregistre l’arbre des types de champ
    # des révisions publiées avant que la publication ne s’en charge. Les
    # révisions en brouillon n’en ont pas : leur arbre change à chaque édition.

    # Deliberately manual: it walks every procedure, and is to be launched once
    # the publication stores the trees. It must not fire on a deploy.

    # Procedures rather than revisions: a plain primary key walk, where picking
    # the revisions which are not a draft would run an anti-join over every
    # procedure with each batch.
    def collection
      Procedure.with_discarded
    end

    def process(procedure)
      backfillable_revisions(procedure).each do |revision|
        coordinates = revision.revision_type_de_champs.to_a
        type_de_champ_tree = TypeDeChampTree.from_coordinates(coordinates)

        # A draft must never store a tree, and the publication stores its own:
        # both are checked again by the statement which writes.
        next if backfillable_revisions(procedure).where(id: revision.id).update_all(type_de_champ_tree:) == 0

        # legacy types de champ without a type, children of a type de champ
        # which is no longer a repetition (revisions published before the
        # publication cleaned them up), stable ids held twice
        left_out = coordinates.size - node_count(type_de_champ_tree.public_children) - node_count(type_de_champ_tree.private_children)
        if left_out > 0
          Rails.logger.warn("#{self.class.name}: revision #{revision.id} (procedure #{procedure.id}) leaves #{left_out} coordinates out of its tree")
        end
      end
    end

    private

    # The draft is read by the database, within the statement: the procedure was
    # loaded with its batch, and may have been published since.
    def backfillable_revisions(procedure)
      draft_revision_id = Procedure.with_discarded.where(id: procedure.id).where.not(draft_revision_id: nil).select(:draft_revision_id)

      ProcedureRevision.where(procedure_id: procedure.id, type_de_champ_tree: nil).where.not(id: draft_revision_id)
    end

    # not `count`: the job reads the size of the collection from Task#count
    def node_count(nodes) = nodes.sum { 1 + node_count(it.children) }
  end
end
