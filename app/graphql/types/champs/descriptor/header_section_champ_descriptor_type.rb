# frozen_string_literal: true

module Types::Champs::Descriptor
  class HeaderSectionChampDescriptorType < Types::BaseObject
    implements Types::ChampDescriptorType

    field :level, Int, null: false

    def level
      object.revision.type_de_champ(object.stable_id).level
    end
  end
end
