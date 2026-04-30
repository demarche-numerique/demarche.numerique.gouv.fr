# frozen_string_literal: true

module AttachmentProcessorConcern
  extend ActiveSupport::Concern

  included do
    after_create_commit :process_later
  end

  private

  def process_later
    return if blob.nil?
    return if blob.byte_size.zero?
    return if blob.processed?

    # Variant blobs and PDF preview images are generated from already-scanned blobs.
    # Mark them safe + processed immediately instead of enqueuing a no-op job.
    if record_type == "ActiveStorage::VariantRecord" || name == "preview_image"
      blob.update_columns(
        virus_scan_result: ActiveStorage::VirusScanner::SAFE,
        virus_scanned_at: Time.current,
        metadata: blob.metadata.merge("processed" => true)
      )
      return
    end

    BlobProcessorJob.perform_later(blob)
  end
end
