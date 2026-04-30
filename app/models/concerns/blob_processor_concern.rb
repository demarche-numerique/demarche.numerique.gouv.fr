# frozen_string_literal: true

module BlobProcessorConcern
  extend ActiveSupport::Concern

  def processed?
    metadata["processed"] == true || virus_scanner.done?
  end

  def watermark_pending?
    watermark_required? && !watermark_done?
  end

  def watermark_done?
    watermarked_at.present?
  end

  def representation_required?
    from_champ? || from_messagerie? || logo? || from_action_text? || from_avis? || from_justificatif_motivation? || from_attestation?
  end

  private

  def from_champ?
    attachments.any? { _1.record.class == Champs::PieceJustificativeChamp }
  end

  def from_messagerie?
    attachments.any? { _1.record.class == Commentaire }
  end

  def logo?
    attachments.any? { _1.name == 'logo' }
  end

  def from_action_text?
    attachments.any? { _1.record.class == ActionText::RichText }
  end

  def from_avis?
    attachments.any? { _1.record.class == Avis }
  end

  def from_justificatif_motivation?
    attachments.any? { _1.name == 'justificatif_motivation' }
  end

  def watermark_required?
    attachments.any? do |attachment|
      record = attachment.record
      next if !record.is_a?(Champs::PieceJustificativeChamp)

      type_de_champ = record.dossier.revision.types_de_champ.find { _1.stable_id == record.stable_id }
      type_de_champ&.titre_identite?
    end
  end

  def from_attestation?
    attachments.any? { _1.record.class == Attestation }
  end
end
