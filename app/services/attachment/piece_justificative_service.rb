# frozen_string_literal: true

class Attachment::PieceJustificativeService
  # ActiveStorage::Attached::Many#attach uses a read-modify-write pattern:
  #   record.piece_justificative_file = blobs + [new_blob]
  # With concurrent uploads, each request reads a stale `blobs` list and
  # overwrites attachments added by other requests (last writer wins).
  # We serialize access with SELECT FOR UPDATE so each request sees
  # the attachments left by the previous one.
  def self.attach_champ_pj(champ, blob_signed_id)
    updated_by = champ.updated_by

    Champ.transaction do
      champ.reload(lock: true) # SELECT FOR UPDATE + clear association cache
      champ.updated_by = updated_by # keep record dirty so attach defers save to us
      champ.piece_justificative_file.attach(blob_signed_id)
      context = champ.public? ? :champs_public_value : :champs_private_value
      champ.save(context:)
    end
  end
end
