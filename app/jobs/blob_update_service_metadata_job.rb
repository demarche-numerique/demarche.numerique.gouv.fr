# frozen_string_literal: true

# `ActiveStorage::Blob#update_service_metadata` pushes the content type and the
# content disposition to the object storage. Rails calls it from an
# `after_update_commit` callback: the record is already committed when it runs,
# so a transient storage error (OVH Swift answering `409 Conflict` on the
# metadata POST) used to turn an already successful user action — sending a
# message with an attachment, for instance — into a HTTP 500.
#
# Doing it from a job keeps the storage round trip out of the request cycle and
# gives it the Sidekiq retries it needs.
class BlobUpdateServiceMetadataJob < ApplicationJob
  use_sidekiq_retry

  discard_on ActiveJob::DeserializationError
  discard_on ActiveStorage::FileNotFoundError

  def perform(blob)
    blob.update_service_metadata_now
  end
end
