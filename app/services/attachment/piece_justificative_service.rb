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
    dossier = champ.dossier

    ChampData.transaction do
      champ.reload(lock: true) # SELECT FOR UPDATE + clear association cache
      # restore the stream-scoped dossier: a fresh association load defaults to
      # the main stream, and conditional visibility (the validation gate) must
      # be computed on the stream being edited
      champ.association(:dossier).target = dossier
      champ.updated_by = updated_by # keep record dirty so attach defers save to us
      champ.piece_justificative_file.attach(blob_signed_id)

      # fetch_later should be called inside the transaction to avoid
      # race condition with processor_job
      champ.fetch_later if champ.has_async_external_data? && champ.may_fetch_later?

      champ.save(context: :champ_value)
    end
  end
end
