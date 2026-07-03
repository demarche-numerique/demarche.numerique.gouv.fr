# frozen_string_literal: true

module Types::Champs
  class SiretChampType < Types::BaseObject
    implements Types::ChampType

    field :etablissement, Types::PersonneMoraleType, null: true

    def etablissement
      return if object.champ_data.nil?

      etablissement = dataloader.with(Sources::Association, :etablissement).load(object.champ_data)
      etablissement unless etablissement&.as_degraded_mode?
    end
  end
end
