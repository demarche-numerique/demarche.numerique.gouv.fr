# frozen_string_literal: true

module Types
  class AnonymousType < Types::BaseObject
    implements Types::DemandeurType

    field :email, String, null: false
  end
end
