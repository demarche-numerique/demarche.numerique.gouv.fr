# frozen_string_literal: true

class BlobService
  # Blobs per purge_blobs_with_variants call, picked by the callers.
  BATCH_SIZE = 1000

  # Objects per Swift bulk delete. Swift deletes them one by one, so the total time
  # depends on the object count, not the request count: a smaller request only adds a
  # round trip, but stays well under the timeouts and costs less to replay.
  BULK_DELETE_LIMIT = 200

  class << self
    # For a batch of expired blobs
    # - keep only the openstack ones (never touch rows/files from another service)
    # - add all the related variant blobs
    # - delete the corresponding files on the openstack bucket
    # - delete in db attachment / variant / blob
    #
    # Returns an audit of every purged blob, one hash per blob:
    #   { id:, key:, file_deleted:, variant:, parent_id: }
    # (parent_id is set only for variant blobs). Each entry is also yielded
    # right after the files are deleted — log there rather than on the return
    # value: a failure while dropping the rows loses the return value, not the
    # yielded entries.
    def purge_blobs_with_variants(parent_ids)
      parents = ActiveStorage::Blob.where(id: parent_ids, service_name: :openstack)
        .pluck(:id, :key)
        .map { |blob_id, key| { blob_id:, key: } }

      blob_id_by_variant_id = ActiveStorage::VariantRecord.where(blob_id: parents.map { it[:blob_id] })
        .pluck(:id, :blob_id)
        .to_h

      # one row per attachment, not a hash keyed by blob_id: two variant records
      # can share the same variant blob, and dropping one of the two attachments
      # would break the attachments.blob_id FK on the blob delete.
      variant_attachments = ActiveStorage::Attachment
        .where(record_type: 'ActiveStorage::VariantRecord', record_id: blob_id_by_variant_id.keys)
        .pluck(:id, :record_id, :blob_id)

      key_by_blob_id = ActiveStorage::Blob
        .where(id: variant_attachments.map { |_, _, blob_id| blob_id })
        .pluck(:id, :key)
        .to_h

      children = variant_attachments.map do |attachment_id, variant_id, blob_id|
        {
          blob_id:,
          key: key_by_blob_id[blob_id],
          parent_blob_id: blob_id_by_variant_id[variant_id],
          variant_id:,
          attachment_id:,
        }
      end

      all = parents.concat(children)

      errored_keys = delete_files(all.map { it[:key] })

      audit = all.map do
        {
          id: it[:blob_id],
          key: it[:key],
          file_deleted: errored_keys.exclude?(it[:key]),
          variant: it[:variant_id].present?,
          parent_id: it[:parent_blob_id],
        }
      end
      audit.each { yield it } if block_given?

      # delete_all bypasses callbacks, so we drop the rows ourselves, in FK order:
      # image attachments -> variant records -> blobs (variants + parents).
      ActiveStorage::Blob.transaction do
        ActiveStorage::Attachment.where(id: all.map { it[:attachment_id] }.compact).delete_all
        # blob_id_by_variant_id.keys, not all.map { it[:variant_id] }: an attachment-less
        # variant record is absent from `all` but still blocks the parent blob delete (FK).
        ActiveStorage::VariantRecord.where(id: blob_id_by_variant_id.keys).delete_all
        ActiveStorage::Blob.where(id: all.map { it[:blob_id] }).delete_all
      end

      audit
    end

    private

    # Bulk-deletes the given keys on the openstack bucket.
    # Returns the keys Swift reported an error for (left on the bucket).
    def delete_files(keys)
      service = ActiveStorage::Blob.service
      client = service.send(:client)

      keys.each_slice(BULK_DELETE_LIMIT).flat_map do |slice|
        response = client.delete_multiple_objects(service.container, slice)
        errors = response.body['Errors']
        next [] if errors.blank?

        Sentry.capture_message("Bulk delete errors", extra: { errors: })
        errors.map { it.first.delete_prefix("#{service.container}/") }
      end
    end
  end
end
