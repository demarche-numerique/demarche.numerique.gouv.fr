# frozen_string_literal: true

class Cron::PurgeSoftDeletedBlobsJob < Cron::CronJob
  self.schedule_expression = "every day at 01:00" # after PurgeUnattachedBlobsJob (00:30)

  # Bounds one run: the Swift bulk delete costs about 30 s per batch, so this is
  # roughly eight hours of work. Whatever is left waits for the next night.
  MAX_BATCHES_PER_RUN = 1000

  def perform
    return if ENV['PURGE_LATER_DELAY_IN_DAY'].blank?
    return if ActiveStorage::Blob.service.name != :openstack

    retention = Integer(ENV['PURGE_LATER_DELAY_IN_DAY']).days
    expired = ActiveStorage::Blob.where(service_name: :openstack, soft_deleted_at: ..retention.ago)

    # Not in_batches: its `ORDER BY id LIMIT n` cursor walks the primary key of
    # the 170M-row blobs table and discards over a million rows before it finds
    # the first batch (45 s in production, hence the statement timeouts).
    # Ordering by soft_deleted_at reads the partial index in order. Every batch
    # deletes its rows, but their index entries stay behind until vacuum, so the
    # cursor keeps the last soft_deleted_at seen as a lower bound: without it,
    # each batch rescans the dead entries of all the previous ones (7 s after
    # 1000 batches on a copy of the production database).
    cursor = nil
    previous_ids = nil
    MAX_BATCHES_PER_RUN.times do
      batch = cursor ? expired.where(soft_deleted_at: cursor..) : expired
      soft_deleted_ats, ids = batch.order(:soft_deleted_at).limit(BlobService::BULK_DELETE_LIMIT)
        .pluck(:soft_deleted_at, :id).transpose

      # ids == previous_ids: the rows survived the purge, so retrying would
      # issue the same Swift bulk delete a thousand times.
      break if ids.blank? || ids == previous_ids

      BlobService.purge_blobs_with_variants(ids)
      cursor = soft_deleted_ats.last
      previous_ids = ids
    end
  end
end
