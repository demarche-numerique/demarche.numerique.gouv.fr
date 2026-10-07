# frozen_string_literal: true

module Recovery
  class Exporter
    FILE_PATH = Rails.root.join('lib', 'data', 'export.dump')

    attr_reader :dossiers, :file_path
    def initialize(dossier_ids:, file_path: FILE_PATH)
      dossier_with_data = Dossier.where(id: dossier_ids)
        .preload(:user,
                 :individual,
                 :invites,
                 :traitements,
                 :transfer_logs,
                 :follows,
                 commentaires: { piece_jointe_attachments: :blob },
                 avis: { introduction_file_attachment: :blob, piece_justificative_file_attachment: :blob },
                 dossier_operation_logs: { serialized_attachment: :blob },
                 attestation: { pdf_attachment: :blob },
                 justificatif_motivation_attachment: :blob,
                 etablissement: :exercices,
                 revision: :procedure)
      @dossiers = DossierPreloader.new(dossier_with_data,
                                       includes_for_champ: [:geo_areas],
                                       includes_for_etablissement: [:exercices]).all
      @file_path = file_path
    end

    def dump
      @file_path.binwrite(Marshal.dump(@dossiers))
    end
  end
end
