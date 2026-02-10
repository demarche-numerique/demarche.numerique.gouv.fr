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
      champ_ids = Champ
        .where(dossier_id: dossier)
        .where(type: ["Champs::PieceJustificativeChamp", 'Champs::TitreIdentiteChamp'])
        .ids

      ActiveStorage::Attachment
        .where(record_id: champ_ids)
        .find_each do |attachment|
          CreateVariantJob.perform_later(attachment.id, file_type:)
        end
    end
  end
end
