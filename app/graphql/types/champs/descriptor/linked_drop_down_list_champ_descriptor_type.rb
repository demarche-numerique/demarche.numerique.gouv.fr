# frozen_string_literal: true

module Types::Champs::Descriptor
  class LinkedDropDownListChampDescriptorType < Types::BaseObject
    implements Types::ChampDescriptorType

    field :options, [String], "List des options d’un champ avec selection.", null: true

    def options
      object.drop_down_options
    end
  end
end
