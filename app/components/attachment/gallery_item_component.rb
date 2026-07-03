# frozen_string_literal: true

class Attachment::GalleryItemComponent < ApplicationComponent
  include GalleryHelper

  attr_reader :attachment
  delegate :blob, :record, to: :attachment

  def initialize(attachment:)
    @attachment = attachment
  end

  def libelle = record_libelle(record).truncate(30)

  def origin
    case record
    in ChampData if record.public?
      t(".dossier_usager")
    in ChampData if record.private?
      t(".annotation_privee")
    in Commentaire if record.instructeur.present?
      t(".messagerie_instructeur")
    in Commentaire if record.expert.present?
      t(".messagerie_expert")
    in Commentaire
      t(".messagerie_usager")
    in Avis if attachment.name == 'introduction_file'
      t(".avis_externe_instructeur")
    in Avis if attachment.name == 'piece_justificative_file'
      t(".avis_externe_expert")
    in Attestation
      t(".attestation_decision")
    else
      if attachment.name == 'justificatif_motivation'
        t(".justificatif_decision")
      end
    end
  end

  def updated?
    record.is_a?(ChampData) && record.public? && updated_at > record.dossier.depose_at
  end

  def updated_at
    blob.created_at
  end
end
