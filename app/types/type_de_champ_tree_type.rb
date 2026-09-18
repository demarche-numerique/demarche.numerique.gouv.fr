# frozen_string_literal: true

class TypeDeChampTreeType < ActiveRecord::Type::Value
  def cast(value)
    case value
    in TypeDeChampTree | NilClass
      value
    in Hash
      TypeDeChampTree.from_json(value)
    end
  end

  # db -> ruby
  def deserialize(value) = cast(value&.then { JSON.parse(it) })

  # ruby -> db
  def serialize(value)
    case value
    in NilClass
      nil
    in TypeDeChampTree
      JSON.generate(value.as_json)
    else
      raise ArgumentError, "Invalid value for TypeDeChampTree serialization: #{value}"
    end
  end
end
