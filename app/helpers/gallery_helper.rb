# frozen_string_literal: true

module GalleryHelper
  def record_libelle(record)
    case record
    in Champ
      record.libelle
    in Commentaire
      'Pièce jointe au message'
    in Avis
      'Pièce jointe à l’avis'
    in Attestation if record.dossier.accepte?
      'Attestation d’acceptation'
    in Attestation if record.dossier.refuse?
      'Attestation de refus'
    else
      if attachment.name == 'justificatif_motivation'
        'Pièce jointe à la décision'
      else
        record.class.model_name.human
      end
    end
  end

  def displayable_pdf?(blob)
    blob.content_type.in?(AUTHORIZED_PDF_TYPES)
  end

  def displayable_image?(blob)
    blob.variable? && blob.content_type.in?(AUTHORIZED_IMAGE_TYPES)
  end

  def variant_url_for(attachment)
    return image_variant_url_for(attachment) if displayable_image?(attachment.blob)

    pdf_preview_variant_url_for(attachment) if displayable_pdf?(attachment.blob)
  end

  def pdf_preview_variant_url_for(attachment)
    preview_image = attachment.blob.preview_image
    return unless preview_image.attached?

    variant = preview_image.variant(resize_to_limit: [400, 400])
    variant.key.present? ? variant.processed.url : nil
  rescue StandardError
  end

  def image_variant_url_for(attachment)
    variant = attachment.variant(resize_to_limit: [400, 400])
    variant.key.present? ? variant.processed.url : nil
  rescue StandardError
  end

  def blob_url(attachment)
    variant = attachment.variant(resize_to_limit: [2000, 2000])
    attachment.blob.content_type.in?(RARE_IMAGE_TYPES) && variant.key.present? ? variant.processed.url : attachment.blob.url
  rescue StandardError
    attachment.blob.url
  end
end
