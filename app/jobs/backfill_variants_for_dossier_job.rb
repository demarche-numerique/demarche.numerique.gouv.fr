# frozen_string_literal: true

class BackfillVariantsForDossierJob < ApplicationJob
  queue_as :low

  retry_on StandardError, wait: 1.minute, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(dossier_id, file_type)
    dossier = Dossier.find(dossier_id)

    champ_ids = Champ
      .where(dossier_id: dossier)
      .where(type: "Champs::PieceJustificativeChamp")
      .ids

    return if champ_ids.empty?

    attachments = ActiveStorage::Attachment
      .includes(:blob)
      .where(record_type: 'Champ', record_id: champ_ids)

    attachments.each do |attachment|
      process_attachment(attachment, file_type)
    end
  end

  private

  def process_attachment(attachment, file_type)
    return if !attachment.representable? || !attachment.representation_required?
    return if skip_attachment?(attachment, file_type)

    if attachment.variable?
      variant = attachment.variant(resize_to_limit: [400, 400])
      variant.processed if variant.key.nil?

      if attachment.blob.content_type.in?(RARE_IMAGE_TYPES)
        large_variant = attachment.variant(resize_to_limit: [2000, 2000])
        large_variant.processed if large_variant.key.nil?
      end
    elsif attachment.previewable?
      preview = attachment.preview(resize_to_limit: [400, 400])
      preview.processed if preview.image.blank?
    end
  rescue Vips::Error, ActiveStorage::Error, EOFError, Excon::Error => e
    Rails.logger.warn "BackfillVariantsForDossierJob: failed to process attachment #{attachment.id}: #{e.message}"
  end

  def skip_attachment?(attachment, file_type)
    content_type = attachment.blob.content_type
    case file_type
    when "image"
      !content_type.in?(AUTHORIZED_IMAGE_TYPES)
    when "pdf"
      !content_type.in?(AUTHORIZED_PDF_TYPES)
    else
      false
    end
  end
end
