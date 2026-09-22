# frozen_string_literal: true

# Walks a selection of dossiers to remove (or to warn about their removal)
# batch by batch. What a failure mid-run can lose is bounded to one batch: a
# retry starts over from the selection, which no longer matches the dossiers
# already processed.
class Removal::Runner
  # A batch grows past this size rather than splitting a user's dossiers.
  BATCH_SIZE = 1000

  # scope: the conditions checked again when a batch is processed, so that a
  # dossier which left the selection in the meantime (edited, sent back to
  # instruction…) is skipped.
  def initialize(scope:)
    @scope = scope
  end

  # ids_and_user_ids: [[dossier_id, user_id], …], plucked from the selection.
  # All the dossiers of one user land in the same batch, hence in the same mail.
  def each_batch(ids_and_user_ids)
    batches = [[]]
    ids_and_user_ids.group_by(&:last).each_value do |user_dossiers|
      batches << [] if batches.last.size >= BATCH_SIZE
      batches.last.concat(user_dossiers.map(&:first))
    end

    batches.each do |ids|
      yield @scope.where(id: ids) if ids.any?
    end
  end
end
