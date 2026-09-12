# frozen_string_literal: true

class Cron::FixMissingAntivirusAnalysisJob < Cron::CronJob
  self.schedule_expression = "every day at 01:45"

  def perform
    # Only process recent blobs (1 week → 1 day ago) to keep the query fast.
    # Older backlog is handled by Maintenance::BackfillVirusScanBlobsTask.
    #
    # .in_batches plucks ids first, then loads records — avoids ORDER BY timeouts
    # on the 150M-row blobs table (same strategy as PurgeUnattachedBlobsJob).
    ActiveStorage::Blob
      .where(created_at: 1.week.ago..1.day.ago)
      .where(virus_scan_result: ActiveStorage::VirusScanner::PENDING)
      .where.not("metadata::jsonb @> ?", '{"processed":true}')
      .in_batches do |relation|
        relation.each { BlobProcessorJob.perform_later(it) }
      end
  end
end
