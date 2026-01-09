# frozen_string_literal: true

module Maintenance
  class UpdateRoutingRulesBasedOnCommuneOrEpciChampTask < MaintenanceTasks::Task
    # Ces 2 tâches mettent à jour les conditions et règles de routage
    # pour les champs communes et ECPI suite à l’ajout de nouveaux opérateurs
    # Voir aussi UpdateConditionsBasedOnCommuneOrEpciChampTask
    # 2023-12-20-01 PR #9850
    include Logic

    def collection
      GroupeInstructeur
        .joins(:procedure)
        .where(procedures: { routing_enabled: true })
    end

    def process(gi)
      routing_rule = gi.routing_rule

      if routing_rule.present?
        tdcs = TypeDeChamp.where(id: gi.procedure.active_revision.types_de_champ_public)

        if tdcs.where(stable_id: routing_rule.sources, type_champ: ["communes", "epci"]).present?
          if routing_rule.is_a?(And)
            new_operands = new_operands_from(tdcs, routing_rule)
            gi.update!(routing_rule: ds_and(new_operands))
          elsif routing_rule.is_a?(Or)
            new_operands = new_operands_from(tdcs, routing_rule)
            gi.update!(routing_rule: ds_or(new_operands))
          elsif routing_rule.is_a?(NotEq)
            gi.update!(routing_rule: ds_not_in_departement(routing_rule.left, routing_rule.right))
          elsif routing_rule.is_a?(Eq)
            gi.update!(routing_rule: ds_in_departement(routing_rule.left, routing_rule.right))
          end
        end
      end
    end

    def count
      collection.count
    end

    private

    def new_operands_from(tdcs, condition)
      condition.operands.map do |sub_condition|
        if tdcs.where(stable_id: sub_condition.sources, type_champ: ["communes", "epci"]).present?
          if sub_condition.is_a?(NotEq)
            ds_not_in_departement(sub_condition.left, sub_condition.right)
          elsif sub_condition.is_a?(Eq)
            ds_in_departement(sub_condition.left, sub_condition.right)
          else
            sub_condition
          end
        else
          sub_condition
        end
      end
    end
  end
end
