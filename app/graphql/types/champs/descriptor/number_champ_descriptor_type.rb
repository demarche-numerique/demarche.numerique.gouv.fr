# frozen_string_literal: true

module Types::Champs::Descriptor
  class NumberChampDescriptorType < Types::BaseObject
    description "Obsolète : plus aucun champ n’est de ce type depuis leur conversion en nombre entier ou décimal (voir `IntegerNumberChampDescriptor` et `DecimalNumberChampDescriptor`). Conservé pour ne pas invalider les requêtes existantes."

    implements Types::ChampDescriptorType
  end
end
