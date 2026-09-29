# frozen_string_literal: true

module Types::Champs::Descriptor
  class DropDownListChampDescriptorType < Types::BaseObject
    implements Types::ChampDescriptorType

    field :options, [String], "List des options d’un champ avec selection.", null: true
    field :other_option, Boolean, "La selection contien l’option \"Autre\".", null: true

    def other_option
      object.drop_down_other?
    end

    def options
      if object.drop_down_advanced?
        # referntiel can contain dosens of thousands of values, we don't want to expose them all
        []
      else
        object.drop_down_options
      end
    end
  end
end
