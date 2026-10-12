# frozen_string_literal: true

# Rejects zero-byte attachments.
#
# An empty file carries no information, and it is also never processed:
# AttachmentProcessorConcern#process_later skips empty blobs, so the blob keeps
# the `pending` virus scan result it gets on create and the attachment stays
# "Analyse antivirus en cours…" forever, neither viewable nor downloadable.
#
# Only blobs being attached by the current save are rejected. An empty
# attachment already committed predates this validation, and flagging it would
# make its record impossible to save at all — an usager could no longer submit
# their dossier. Those are cleaned up by
# Maintenance::T20260728PurgeEmptyAttachmentsTask instead.
class EmptyFileValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.is_a?(ActiveStorage::Attached) && !record.attachment_changes.key?(attribute.to_s)

    blobs(value).each do
      next unless it.byte_size == 0
      next if already_attached?(record, attribute, it)

      record.errors.add(attribute, :file_empty, filename: it.filename.to_s)
    end
  end

  private

  # Attached::Many exposes #blobs, Attached::One only #blob. A record holding a
  # signed id it has not attached yet (BatchOperation payload) exposes neither.
  def blobs(value)
    case value
    when ActiveStorage::Attached::Many then value.blobs
    when ActiveStorage::Attached::One then [value.blob].compact
    when String then [ActiveStorage::Blob.find_signed(value)].compact
    else []
    end
  end

  # Attachments are inserted after validation, so a blob already joined to this
  # record in database was attached by an earlier save, not by this one.
  def already_attached?(record, attribute, blob)
    return false if record.new_record? || blob.id.nil?

    ActiveStorage::Attachment.exists?(record:, name: attribute.to_s, blob_id: blob.id)
  end
end
