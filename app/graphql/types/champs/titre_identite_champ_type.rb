# frozen_string_literal: true

module Types::Champs
  class TitreIdentiteChampType < Types::BaseObject
    implements Types::ChampType

    # Constants moved from deleted TypesDeChamp::TitreIdentiteTypeDeChamp (kept for GraphQL backward compatibility)
    FRANCE_CONNECT = 'france_connect'
    PIECE_JUSTIFICATIVE = 'piece_justificative'

    class TitreIdentiteGrantTypeType < Types::BaseEnum
      value(FRANCE_CONNECT, "Françe Connect")
      value(PIECE_JUSTIFICATIVE, "Pièce justificative")
    end

    field :grant_type, TitreIdentiteGrantTypeType, null: false
    field :filled, Boolean, null: false

    def grant_type
      PIECE_JUSTIFICATIVE
    end

    def filled
      object.piece_justificative_file.attached?
    end
  end
end
