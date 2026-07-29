# frozen_string_literal: true

module Types::Champs::Descriptor
  class HeaderSectionChampDescriptorType < Types::BaseObject
    implements Types::ChampDescriptorType

    field :level, Int, null: false

    def level
      object.revision.find_type_de_champ_by_stable_id(object.type_de_champ.stable_id).level
    end
  end
end
