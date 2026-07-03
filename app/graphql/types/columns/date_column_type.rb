# frozen_string_literal: true

module Types::Columns
  class DateColumnType < Types::BaseObject
    implements Types::ColumnType

    field :value, GraphQL::Types::ISO8601Date, null: true, extras: [:parent]

    def value(parent:)
      object.value(column_target(parent))
    end
  end
end
