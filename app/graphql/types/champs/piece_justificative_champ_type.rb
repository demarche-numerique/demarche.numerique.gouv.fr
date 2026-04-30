# frozen_string_literal: true

module Types::Champs
  class PieceJustificativeChampType < Types::BaseObject
    implements Types::ChampType

    field :file, Types::File, null: true, deprecation_reason: "Utilisez le champ `files` à la place.", extensions: [
      Extensions::TitreIdentiteGuard,
      { Extensions::Attachment => { attachments: :piece_justificative_file, as: :single } },
    ]

    field :nature, String, null: false, description: "La nature de la pièce justificative. ex: 'NON_SPECIFIE', 'TITRE_IDENTITE', 'RIB', 'JUSTIFICATIF_DOMICILE'"

    field :files, [Types::File], null: false, extensions: [
      Extensions::TitreIdentiteGuard,
      { Extensions::Attachment => { attachments: :piece_justificative_file } },
    ]

    def nature
      (object.nature || "non_specifie").upcase
    end
  end
end
