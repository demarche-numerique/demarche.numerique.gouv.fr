# frozen_string_literal: true

module Types::Champs
  class EngagementJuridiqueChampType < Types::BaseObject
    implements Types::ChampType

    class EngagementJuridiqueType < Types::BaseObject
      field :montant_engage, String, null: true
      field :montant_paye, String, null: true

      def numero
        object.value
      end

      def montant_engage
        "NotYetImplemented"
      end

      def montant_paye
        "NotYetImplemented"
      end
    end

    field :engagement_juridique, EngagementJuridiqueType, "Montant engagé et payé de l’EJ.", null: true

    def engagement_juridique
      object if object.value.present?
    end
  end
end
