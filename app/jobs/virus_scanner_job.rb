# frozen_string_literal: true

# DEPRECATED: Re-enqueues as BlobProcessorJob for backward compatibility during deployment.
# BlobProcessorJob handles virus scanning + image processing in a single pipeline.
# Remove once Sidekiq queues are fully drained of old VirusScannerJob entries.
class VirusScannerJob < ApplicationJob
  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveStorage::FileNotFoundError

  def perform(blob)
    BlobProcessorJob.perform_later(blob)
  end
end
