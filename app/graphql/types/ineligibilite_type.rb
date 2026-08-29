# frozen_string_literal: true

module Types
  class IneligibiliteType < Types::BaseObject
    graphql_name "Ineligibilite"
    description "Règle d’inéligibilité d’une révision : un dossier qui la vérifie ne peut pas être déposé."

    field :message, String, "Message affiché à l’usager lorsque le dossier est inéligible.", null: false, method: :ineligibilite_message
    field :rule, Types::LogicExpression, "Règle d’inéligibilité.", null: false
    field :rule_expression, String, "Règle d’inéligibilité, rendue sous forme de s-expression.", null: false

    def rule
      object.ineligibilite_rules.to_expr
    end

    def rule_expression
      object.ineligibilite_rules.to_sexp
    end
  end
end
