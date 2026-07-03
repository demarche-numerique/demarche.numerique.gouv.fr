# frozen_string_literal: true

module Types::Columns
  class DecimalColumnType < Types::BaseObject
    implements Types::ColumnType

    field :value, Float, null: true, extras: [:parent]

    def value(parent:)
      object.value(column_target(parent))
    end
  end
end
