# frozen_string_literal: true

module Maintenance
  class CreateVariantsForPjOfLatestDossiersTask < MaintenanceTasks::Task
    # Génère les vignettes de fichiers (images et/ou PDF) pour les dossiers déposés entre 2 dates (facultatif).
    # 2024-07-11-01
    # Elles sont affichées dans le nouvel onglet "Pièces jointes" des instructeurs.
    # Le paramètre file_type permet de cibler : "image", "pdf", ou les deux (vide).
    attribute :start_text, :string
    validates :start_text, presence: true

    attribute :end_text, :string
    validates :end_text, presence: true

    attribute :file_type, :string
    validates :file_type, inclusion: { in: ['image', 'pdf', ''] }

    def collection
      start_date = DateTime.parse(start_text)
      end_date = DateTime.parse(end_text)

      Dossier
        .state_en_construction_ou_instruction
        .where(depose_at: start_date..end_date)
    end

    def process(dossier)
      require "vips"

      champ_ids = Champ
        .where(dossier_id: dossier)
        .where(type: "Champs::PieceJustificativeChamp")
        .ids

      attachments = ActiveStorage::Attachment
        .where(record_id: champ_ids)

      attachments.each do |attachment|
        next if !attachment.representable? || !attachment.representation_required?
        next if skip_attachment?(attachment)

        if attachment.variable?
          attachment.variant(resize_to_limit: [400, 400]).processed if attachment.variant(resize_to_limit: [400, 400]).key.nil?
          if attachment.blob.content_type.in?(RARE_IMAGE_TYPES) && attachment.variant(resize_to_limit: [2000, 2000]).key.nil?
            attachment.variant(resize_to_limit: [2000, 2000]).processed
          end
        elsif attachment.previewable?
          attachment.representation(resize_to_limit: [400, 400]).processed
        end
      rescue Vips::Error, ActiveStorage::Error
      end
    end

    private

    def skip_attachment?(attachment)
      content_type = attachment.blob.content_type
      case file_type
      when 'image'
        !content_type.in?(AUTHORIZED_IMAGE_TYPES)
      when 'pdf'
        !content_type.in?(AUTHORIZED_PDF_TYPES)
      else
        false
      end
    end
  end
end
