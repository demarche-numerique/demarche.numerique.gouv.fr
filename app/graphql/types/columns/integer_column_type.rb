# frozen_string_literal: true

module Types::Columns
  class IntegerColumnType < Types::BaseObject
    implements Types::ColumnType

    field :value, GraphQL::Types::BigInt, null: true, extras: [:parent]

    def value(parent:)
      object.value(column_target(parent))
    end
  end
end
