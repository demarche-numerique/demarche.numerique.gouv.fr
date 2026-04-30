# frozen_string_literal: true

class BatchOperationProcessOneJob < ApplicationJob
  queue_as :critical
  retry_on StandardError, attempts: 1 # default 5, for now no retryable behavior

  def perform(batch_operation, dossier)
    dossier = batch_operation.dossiers_safe_scope.find(dossier.id)
    begin
      ActiveRecord::Base.transaction do
        batch_operation.process_one(dossier)
        batch_operation.track_processed_dossier(true, dossier)
      end
    rescue => error
      ActiveRecord::Base.transaction do
        batch_operation.track_processed_dossier(false, dossier)
      end
      raise error
    ensure
      batch_operation.finalize_if_complete!
    end
  rescue ActiveRecord::RecordNotFound
    dossier.update_column(:batch_operation_id, nil)
    batch_operation.finalize_if_complete!
  end
end
