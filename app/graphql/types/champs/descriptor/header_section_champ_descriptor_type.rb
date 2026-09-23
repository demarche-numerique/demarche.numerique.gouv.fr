# frozen_string_literal: true

module Types::Champs::Descriptor
  class HeaderSectionChampDescriptorType < Types::BaseObject
    implements Types::ChampDescriptorType

    field :level, Int, null: false

    # the coordinate's own type de champ is not laid out: the revision's is
    def level
      object.revision.type_de_champ(object.stable_id).absolute_level
    end
  end
end
