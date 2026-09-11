# frozen_string_literal: true

module GalleryHelper
  def record_libelle(record)
    case record
    in ChampData
      # a champ and its attachments can outlive its type_de_champ in the dossier
      # revision; the gallery must render anyway
      in_revision = record.dossier.revision.type_de_champs.any? { it.stable_id == record.stable_id }
      in_revision ? record.libelle : 'Pièce jointe'
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

    existing_variant_url(preview_image.variant(resize_to_limit: [400, 400]))
  end

  def image_variant_url_for(attachment)
    return if !attachment.blob.variable?

    existing_variant_url(attachment.variant(resize_to_limit: [400, 400]))
  end

  def blob_url(attachment)
    return attachment.blob.url if !attachment.blob.content_type.in?(RARE_IMAGE_TYPES) || !attachment.blob.variable?

    existing_variant_url(attachment.variant(resize_to_limit: [2000, 2000])) || attachment.blob.url
  end

  private

  def existing_variant_url(variant)
    variant.url if variant.image&.attached?
  end
end
