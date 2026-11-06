# frozen_string_literal: true

module Maintenance
  # Destroys the drafts a double publication left behind (#14276): never
  # published, and neither the draft nor the published revision of their
  # procedure. The dossiers and traitements foreign keys stop the destroy of a
  # revision still in use.
  class T20261015destroyOrphanDraftRevisionsTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    def collection
      ProcedureRevision
        .where(published_at: nil)
        .where.not(id: Procedure.with_discarded.where.not(draft_revision_id: nil).select(:draft_revision_id))
        .where.not(id: Procedure.with_discarded.where.not(published_revision_id: nil).select(:published_revision_id))
    end

    def process(revision)
      ProcedureRevision.transaction do
        # a revision shares its dossier submitted message with the revisions
        # cloned from it: destroying it would take the message from them
        message_id = revision.dossier_submitted_message_id
        if message_id && ProcedureRevision.where(dossier_submitted_message_id: message_id).where.not(id: revision.id).exists?
          revision.update_columns(dossier_submitted_message_id: nil)
        end

        revision.destroy!
      end
    end
  end
end
