# frozen_string_literal: true

module Types
  class LogicExpression < Types::BaseScalar
    description <<~DESC
      Expression logique en notation préfixée, encodée en tableaux JSON.

      Un terme est soit une référence à un champ `["champ", <id du ChampDescriptor>]`
      ou à une de ses colonnes `["column", <id du ChampDescriptor>, <colonne>]`,
      soit une constante (chaîne, nombre ou booléen), soit `null` (vide),
      soit une opération `[<opérateur>, <terme>, <terme>, …]`.

      Opérateurs binaires : `=`, `!=`, `<`, `<=`, `>`, `>=`, `empty?`, `includes`, `excludes`,
      `in-departement`, `not-in-departement`, `in-region`, `not-in-region`.
      Opérateurs n-aires : `and`, `or`.

      Exemple : `["and", ["=", ["champ", "Q2hhbXAtMQ=="], "oui"], [">=", ["champ", "Q2hhbXAtMg=="], 18]]`
    DESC

    def self.coerce_result(ruby_value, _context)
      ruby_value
    end

    def self.coerce_input(input_value, _context)
      Logic.from_expr(input_value)
      input_value
    rescue ArgumentError => e
      raise GraphQL::CoercionError, e.message
    end
  end
end
