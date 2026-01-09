# frozen_string_literal: true

module RoutingRuleStatusesConcern
  extend ActiveSupport::Concern

  included do
    def update_all_groupes_rule_validity_status
      valid_ids = []
      invalid_ids = []

      self.groupe_instructeurs.includes(:procedure).find_each do |gi|
        if gi.valid_rule?
          valid_ids << gi.id
        else
          invalid_ids << gi.id
        end
      end

      GroupeInstructeur.where(id: valid_ids).update_all(valid_routing_rule: true)
      GroupeInstructeur.where(id: invalid_ids).update_all(valid_routing_rule: false)
    end

    def update_all_groupes_rule_unicity_status
      # Get ids from groupe_instructeurs with same routing rule
      rule_gis = Hash.new { |h, k| h[k] = [] }

      self.groupe_instructeurs.each_with_object(rule_gis) do |gi, h|
        h[gi.routing_rule] << gi.id
      end

      duplicate_ids = rule_gis.filter { |_k, gi_ids| gi_ids.size > 1 }.map(&:second).flatten

      # Update unique_routing_rule in all groups
      self.groupe_instructeurs.update_all(unique_routing_rule: true)
      self.groupe_instructeurs.where(id: duplicate_ids).update_all(unique_routing_rule: false)
    end

    def update_all_groupes_rule_statuses
      update_all_groupes_rule_validity_status
      update_all_groupes_rule_unicity_status
    end
  end
end
