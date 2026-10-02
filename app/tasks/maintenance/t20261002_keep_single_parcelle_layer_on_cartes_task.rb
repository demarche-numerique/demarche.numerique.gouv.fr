# frozen_string_literal: true

module Maintenance
  class T20261002KeepSingleParcelleLayerOnCartesTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    PARCELLE_LAYERS = TypesDeChamp::CarteTypeDeChamp::PARCELLE_LAYERS

    # The parcelle layers are exclusive, but only since a save enforces it:
    # the cartes saved earlier with both keep the first one, cadastres, as
    # carte_optional_layers reads them.

    # Coarse on purpose: process decides what enabled means.
    def collection
      TypesDeChamp::CarteTypeDeChamp.where("options->>'cadastres' IS NOT NULL AND options->>'rpg' IS NOT NULL")
    end

    def process(type_de_champ)
      extra_layers = PARCELLE_LAYERS.filter { type_de_champ.layer_enabled?(it) }.drop(1)
      return if extra_layers.empty?

      type_de_champ.update_column(:options, type_de_champ.options.merge(extra_layers.map(&:to_s).index_with { false }))
    end
  end
end
