# frozen_string_literal: true

module Types::GeoAreas
  class RpgType < Types::BaseObject
    implements Types::GeoAreaType

    field :numero, String, null: true
    field :surface, Float, null: true
    field :commune, String, null: true
  end
end
