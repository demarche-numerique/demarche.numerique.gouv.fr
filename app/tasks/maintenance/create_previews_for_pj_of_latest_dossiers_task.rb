# frozen_string_literal: true

module Maintenance
  class CreatePreviewsForPjOfLatestDossiersTask < MaintenanceTasks::Task
    # Génère les vignettes de PJ existantes pour les dossiers déposés entre 2 dates (facultatif)
    # Elles sont affichées dans le nouvel onglet "Pièces jointes" des instructeurs.
    # 2024-07-11-01
    attribute :start_text, :string
    validates :start_text, presence: true

    attribute :end_text, :string
    validates :end_text, presence: true

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
        next if !(attachment.previewable? && attachment.representation_required?)
        attachment.preview(resize_to_limit: [400, 400]).processed unless attachment.preview(resize_to_limit: [400, 400]).image.attached?
      rescue Vips::Error, ActiveStorage::Error
      end
    end
  end
end
