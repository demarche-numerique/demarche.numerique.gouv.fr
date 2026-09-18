# frozen_string_literal: true

module Maintenance
  class T20260918BackfillProcedureRevisionTypeDeChampTreeTask < MaintenanceTasks::Task
    # Documentation: cette tâche calcule et enregistre l’arbre des types de champ
    # des révisions qui n’en ont pas encore : celles publiées avant que la
    # publication ne s’en charge, et les brouillons pas modifiés depuis que
    # chaque édition enregistre le leur.

    # Deliberately manual: it walks every procedure, and is to be launched once
    # the publication and the editor store the trees. It must not fire on a
    # deploy.

    # Procedures rather than revisions: a plain primary key walk.
    def collection
      Procedure.with_discarded
    end

    def process(procedure)
      ProcedureRevision.where(procedure_id: procedure.id, type_de_champ_tree: nil).find_each do |revision|
        # As an edit of the draft does, under the lock of the revision: the
        # tree an edit or a publication stored since the revision was read is
        # built from the same coordinates, and is left as it is.
        type_de_champ_tree = revision.store_type_de_champ_tree.type_de_champ_tree

        # legacy types de champ without a type, children of a type de champ
        # which is no longer a repetition (revisions published before the
        # publication cleaned them up), stable ids held twice
        left_out = revision.revision_type_de_champs.size - type_de_champ_tree.nodes.size
        if left_out > 0
          Rails.logger.warn("#{self.class.name}: revision #{revision.id} (procedure #{procedure.id}) leaves #{left_out} coordinates out of its tree")
        end
      end
    end
  end
end
