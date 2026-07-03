# frozen_string_literal: true

module Types::Champs
  class CarteChampType < Types::BaseObject
    implements Types::ChampType

    field :geo_areas, [Types::GeoAreaType], null: false

    def geo_areas
      return [] if object.champ_data.nil?

      dataloader.with(Sources::Association, :geo_areas).load(object.champ_data)
    end
  end
end
