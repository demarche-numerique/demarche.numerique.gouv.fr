# frozen_string_literal: true

module Types::Champs::Descriptor
  class DateChampDescriptorType < Types::BaseObject
    implements Types::ChampDescriptorType

    field :birthdate, Boolean, "Ce champ est une date de naissance.", null: true

    def birthdate
      object.type_de_champ.birthdate?
    end
  end
end
