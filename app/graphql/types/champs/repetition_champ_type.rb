# frozen_string_literal: true

module Types::Champs
  class RepetitionChampType < Types::BaseObject
    implements Types::ChampType

    class Row < Types::BaseObject
      global_id_field :id
      field :champs, [Types::ChampType], null: false
    end

    field :champs, [Types::ChampType], null: false, deprecation_reason: 'Utilisez le champ `rows` à la place.'
    field :rows, [Row], null: false

    def champs
      object.rows.flat_map { it.flat_champs.filter(&:visible?) }
    end

    def rows
      object
        .rows
        .map do
          {
            id: GraphQL::Schema::UniqueWithinType.encode('Row', it.id),
            champs: it.flat_champs.filter(&:visible?),
          }
        end
    end
  end
end
