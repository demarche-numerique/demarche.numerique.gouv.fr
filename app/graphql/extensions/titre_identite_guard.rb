# frozen_string_literal: true

module Extensions
  # GraphQL field extension acting as a guard.
  #
  # Field extensions chain via `yield`: not calling `yield` in `resolve`
  # short-circuits all downstream extensions and the field resolver.
  # Listed before other extensions in the `extensions:` array to wrap them.
  #
  # @see https://graphql-ruby.org/type_definitions/field_extensions.html
  class TitreIdentiteGuard < GraphQL::Schema::FieldExtension
    def resolve(object:, arguments:, context:)
      if object.object.titre_identite?
        field.type.list? ? [] : nil
      else
        yield(object, arguments)
      end
    end
  end
end
