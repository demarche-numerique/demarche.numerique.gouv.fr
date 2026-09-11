# frozen_string_literal: true

class Cron::PurgeUnattachedBlobsJob < Cron::CronJob
  self.schedule_expression = "every day at 00:30"

  # The anti-join with active_storage_attachments (130M rows) must be a nested
  # loop probing the blob_id index, not a hash join over a full seq scan of the
  # table (60 s, the statement timeouts). The planner keeps the nested loop as
  # long as it expects few blobs on the outer side: it underestimates an id
  # range 200-fold today, but a week-wide range would flip to the seq scan once
  # estimated accurately (an index on created_at, extended statistics). 100k
  # ids stays far below the flip point either way: 0.1 s per slice.
  ID_SLICE = 100_000

  def perform
    # Blobs created 1 week → 1 day ago: a day for an upload to be attached, and
    # the job has to run at least once a week not to miss any.
    window = 1.week.ago..1.day.ago

    # Ids grow with created_at (observed lag: a minute at most), so the window
    # is an id range whose bounds come from a backward walk of the primary key:
    # no index on created_at needed. Never backdate a blob's created_at: a
    # single blob with an old created_at and a recent id would push first_id
    # past the whole window and the run would silently purge nothing.
    first_id = ActiveStorage::Blob.where(created_at: ...window.begin).order(id: :desc).pick(:id).to_i + 1
    last_id = ActiveStorage::Blob.where(created_at: ..window.end).order(id: :desc).pick(:id)
    return if last_id.nil? || last_id < first_id

    (first_id..last_id).step(ID_SLICE) do |from|
      ActiveStorage::Blob
        .where(id: from..[from + ID_SLICE - 1, last_id].min)
        .where(created_at: window, soft_deleted_at: nil)
        .unattached
        .select(:id, :service_name)
        .each(&:purge_later)
    end
  end
end
