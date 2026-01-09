# frozen_string_literal: true

module Maintenance
  class UpdateConditionsBasedOnCommuneOrEpciChampTask < MaintenanceTasks::Task
    # Met à jour les conditions et règles de routage
    # pour les champs communes et ECPI suite à l’ajout de nouveaux opérateurs
    # Voir aussi UpdateRoutingRulesBasedOnCommuneOrEpciChampTask
    # 2023-12-20-01 PR #9850
    include Logic

    def collection
      ProcedureRevision.all
    end

    def process(revision)
      tdc_to_update_ids = []

      tdcs = TypeDeChamp.where(id: revision.types_de_champ_public)

      tdcs.where.not(condition: nil).pluck(:condition, :id).each do |condition, id|
        if tdcs.where(stable_id: condition.sources, type_champ: ["communes", "epci"]).present?
          tdc_to_update_ids << id
        end
      end

      tdc_to_update_ids.each do |id|
        tdc = tdcs.find_by(id:)

        condition = tdc.condition

        if condition.is_a?(And)
          new_operands = new_operands_from(tdcs, condition)
          tdc.update!(condition: ds_and(new_operands))
        elsif condition.is_a?(Or)
          new_operands = new_operands_from(tdcs, condition)
          tdc.update!(condition: ds_or(new_operands))
        elsif condition.is_a?(NotEq)
          tdc.update!(condition: ds_not_in_departement(condition.left, condition.right))
        elsif condition.is_a?(Eq)
          tdc.update!(condition: ds_in_departement(condition.left, condition.right))
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
