# frozen_string_literal: true

class ClonePiecesJustificativesService
  def self.clone_attachments(original, kopy)
    case original
    when Champs::PieceJustificativeChamp
      clone_many_attachments(original, kopy, :piece_justificative_file)
    when TypeDeChamp
      clone_one_attachment(original, kopy, :piece_justificative_template)
    when Procedure
      clone_one_attachment(original, kopy, :logo)
      clone_one_attachment(original, kopy, :notice)
      clone_one_attachment(original, kopy, :deliberation)
    when AttestationTemplate
      clone_one_attachment(original, kopy, :logo)
      clone_one_attachment(original, kopy, :signature)
    when Etablissement
      clone_one_attachment(original, kopy, :entreprise_attestation_sociale)
      clone_one_attachment(original, kopy, :entreprise_attestation_fiscale)
    when GroupeInstructeur
      clone_one_attachment(original, kopy, :signature)
    end
  end

  def self.clone_many_attachments(original, kopy, attachments_name)
    original.public_send(attachments_name).attachments.each do |attachment|
      kopy.public_send(attachments_name).attach(attachment.blob)
    end
  end

  def self.clone_one_attachment(original, kopy, attachment_name)
    attachment = original.public_send(attachment_name)
    if attachment.attached?
      kopy.public_send(attachment_name).attach(attachment.blob)
    end
  end
end
