# frozen_string_literal: true

module Types
  module DemandeurType
    include Types::BaseInterface

    global_id_field :id

    definition_methods do
      def resolve_type(object, context)
        case object
        when User
          Types::AnonymousType
        when Individual
          Types::PersonnePhysiqueType
        when Etablissement
          if object.as_degraded_mode? && context.has_fragment?(:PersonneMoraleIncomplete)
            Types::PersonneMoraleIncompleteType
          else
            Types::PersonneMoraleType
          end
        end
      end
    end
  end
end
