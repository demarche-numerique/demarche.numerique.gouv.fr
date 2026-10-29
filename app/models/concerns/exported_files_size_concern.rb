# frozen_string_literal: true

# Sums the files a zip export or an archive ships for a set of dossiers, read
# off the blob sizes: the zip stores them uncompressed, so the sum is a
# faithful prediction of its size.
module ExportedFilesSizeConcern
  extend ActiveSupport::Concern

  # Size of the export-<id>.pdf that opens every dossier folder, measured on the
  # 84 k dossier PDFs stored in production (2026-09): p50 104 kB, p90 129 kB.
  DOSSIER_PDF_WEIGHT = 110.kilobytes

  private

  def exported_files_size(dossier_ids, export_template: nil)
    attachments_size = exported_attachment_sources(dossier_ids, export_template).sum do |record_type, names, record_ids|
      exported_attachments_size(record_type, names, record_ids)
    end

    pdfs_size = export_template.nil? || export_template.export_pdf.enabled? ? dossier_ids.size * DOSSIER_PDF_WEIGHT : 0

    pdfs_size + attachments_size
  end

  # The attachments PiecesJustificativesService puts in a zip, by owner, and
  # those an export template keeps. Titres d'identité are skipped: they are
  # another champ type, so the type filter leaves them out. The zip ships the
  # current value of every champ: the history streams keep their own copies of
  # the pièces jointes they replaced.
  def exported_attachment_sources(dossier_ids, export_template)
    all = export_template.nil?
    sources = [['Champ', 'piece_justificative_file', exported_pj_champs(dossier_ids, export_template).select(:id)]]

    sources << ['Commentaire', 'piece_jointe', Commentaire.where(dossier_id: dossier_ids).select(:id)] if all || export_template.commentaires_attachments
    sources << ['Dossier', 'justificatif_motivation', dossier_ids] if all || export_template.justificatif_motivation
    sources << ['Attestation', 'pdf', Attestation.where(dossier_id: dossier_ids).select(:id)] if all || export_template.attestation.enabled?
    sources << ['Avis', ['introduction_file', 'piece_justificative_file'], Avis.where(dossier_id: dossier_ids).select(:id)] if all || export_template.avis_attachments
    # ExportTemplate#attachment_path has no path for them
    sources << ['Etablissement', ['entreprise_attestation_sociale', 'entreprise_attestation_fiscale'], Etablissement.where(dossier_id: dossier_ids).select(:id)] if all

    sources
  end

  # A rebase keeps the champs of a pièce justificative removed from the
  # revision, and a dossier keeps the champs of a removed repetition row until
  # its decision, while the zip only ships the champs the dossier shows.
  def exported_pj_champs(dossier_ids, export_template)
    enabled_stable_ids = export_template.pjs.filter(&:enabled?).map(&:stable_id) if export_template
    dossier_ids_by_revision = Dossier.where(id: dossier_ids).pluck(:revision_id, :id).group_by(&:first).transform_values { it.map(&:last) }
    revisions = ProcedureRevision.includes(revision_type_de_champs: :type_de_champ).where(id: dossier_ids_by_revision.keys).index_by(&:id)

    champs_by_revision = dossier_ids_by_revision.map do |revision_id, revision_dossier_ids|
      stable_ids = revisions.fetch(revision_id).type_de_champs.filter(&:piece_justificative?).map(&:stable_id)
      stable_ids &= enabled_stable_ids if export_template

      ChampData.where(dossier_id: revision_dossier_ids, stable_id: stable_ids)
    end

    # the row champs carry the stable_id of their repetition: without it, the
    # planner scans the whole champs table for 10 000 dossiers
    repetition_stable_ids = revisions.values.flat_map { it.type_de_champs.filter(&:repetition?).map(&:stable_id) }.uniq
    discarded_row_ids = ChampData.where(dossier_id: dossier_ids, stream: Dossier::MAIN_STREAM, stable_id: repetition_stable_ids).where.not(discarded_at: nil).select(:row_id)
    pj_champs = ChampData.where(type: Champs::PieceJustificativeChamp.to_s, stream: Dossier::MAIN_STREAM).and(champs_by_revision.reduce(:or))

    pj_champs.where(row_id: nil).or(pj_champs.where.not(row_id: discarded_row_ids))
  end

  # One query per owner keeps every plan a semi join on the attachments
  # uniqueness index; a single OR over the sources tempts the planner into a
  # scan of the whole table.
  def exported_attachments_size(record_type, names, record_ids)
    ActiveStorage::Attachment
      .joins(:blob)
      .where(record_type:, name: names, record_id: record_ids)
      # what the zip skips too: purged blobs, and blobs not (yet) scanned safe
      .where(active_storage_blobs: { soft_deleted_at: nil, virus_scan_result: ActiveStorage::VirusScanner::SAFE })
      .sum('active_storage_blobs.byte_size')
  end
end
