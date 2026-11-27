# frozen_string_literal: true

module Mutations
  class DemarcheModifierChampCondition < Mutations::DemarcheBrouillonMutation
    description "Définir la condition d’affichage d’un champ du brouillon d’une démarche. Sans terme, la condition est retirée."

    class Combinateur < Types::BaseEnum
      graphql_name 'ConditionCombinateur'

      value('et', "Tous les termes doivent être vérifiés", value: 'and')
      value('ou', "Un des termes doit être vérifié", value: 'or')
    end

    class Operateur < Types::BaseEnum
      graphql_name 'ConditionOperateur'

      DraftEditorService::OPERATORS.each do |name, operator_class|
        value(name, I18n.t(operator_class.name, scope: 'logic.operators', default: name), value: name)
      end
    end

    class TermeInput < Types::BaseInputObject
      graphql_name 'ConditionTermeInput'
      description "Un terme de la condition : la comparaison d’un champ placé avant le champ conditionné à une valeur."

      argument :champ_id, ID, "Le champ comparé.", required: true
      argument :operateur, Operateur, required: true
      argument :valeur, String, "La valeur à laquelle le champ est comparé : un nombre, `true` ou `false`, une option d’une liste, un code de département ou de région.", required: true
      argument :colonne, String, "L’information du champ comparée, quand ce n’est pas sa valeur.", required: false
    end

    argument :champ_id, ID, "Le champ conditionné.", required: true
    argument :combinateur, Combinateur, required: false, default_value: 'and'
    argument :termes, [TermeInput], required: true

    private

    def edit(editor, champ_id:, termes:, combinateur: 'and')
      terms = termes.map do |terme|
        { source_stable_id: stable_id_from(terme.champ_id), operator: terme.operateur, value: terme.valeur, source_column: terme.colonne }
      end

      editor.set_condition(stable_id_from(champ_id), operator: combinateur, terms:)
    end
  end
end
