# frozen_string_literal: true

module ProcedureGroupeInstructeurAPIHackConcern
  extend ActiveSupport::Concern

  include Logic

  # ugly hack to keep retro compatibility
  # do not judge
  def update_groupe_instructeur_routing_roules!
    if feature_enabled?(:groupe_instructeur_api_hack)
      stable_id = groupe_instructeurs.first.routing_rule.left.stable_id
      tdc = published_revision.types_de_champ.find { _1.stable_id == stable_id }

      drop_down_options = groupe_instructeurs.active.map do |groupe_instructeur|
        groupe_instructeur.update!(routing_rule: ds_eq(champ_value(stable_id), constant(groupe_instructeur.label)))
        groupe_instructeur.label
      end

      tdc.update!(drop_down_options:)

      self.update_all_groupes_rule_statuses
    end
  end
end
