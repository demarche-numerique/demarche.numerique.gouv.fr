# frozen_string_literal: true

module Types
  class RoutingRuleType < Types::BaseObject
    graphql_name "RoutingRule"
    description "Un groupe instructeur et la règle qui lui affecte des dossiers."

    field :number, Int, "Le numero du groupe instructeur.", null: false, method: :id
    field :label, String, "Libellé du groupe instructeur.", null: false
    field :defaut, Boolean, "Groupe qui reçoit les dossiers qu’aucune règle ne route.", null: false, method: :defaut?
    field :rule, Types::LogicExpression, "Règle de routage.", null: false
    field :rule_expression, String, "Règle de routage, rendue sous forme de s-expression.", null: false

    def rule
      object.routing_rule.to_expr
    end

    def rule_expression
      object.routing_rule.to_sexp
    end
  end
end
