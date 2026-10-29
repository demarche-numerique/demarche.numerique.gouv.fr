# frozen_string_literal: true

module Maintenance
  # Dates the published revisions left without publication date, which the
  # modifications history cannot display (#14276). On publication, the next
  # draft is cloned from the published revision, so its creation dates the
  # publication.
  class T20261015backfillPublishedRevisionPublishedAtTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    def collection
      ProcedureRevision
        .where(published_at: nil)
        .where(id: Procedure.with_discarded.select(:published_revision_id))
    end

    def process(revision)
      next_revision = ProcedureRevision.where(procedure_id: revision.procedure_id).where('id > ?', revision.id).order(:id).first
      revision.update_columns(published_at: next_revision.created_at)
    end
  end
end
