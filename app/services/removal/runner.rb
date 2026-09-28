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

  # Walks `selection`, the scope itself unless a narrower relation is given (a
  # daily limit, an order the index serves). All the dossiers of one user land
  # in the same batch, hence in the same mail.
  def each_batch(selection = @scope)
    batches = [[]]
    selection.pluck(:id, :user_id).group_by(&:last).each_value do |user_dossiers|
      batches << [] if batches.last.size >= BATCH_SIZE
      batches.last.concat(user_dossiers.map(&:first))
    end

    batches.each do |ids|
      yield @scope.where(id: ids) if ids.any?
    end
  end
end
