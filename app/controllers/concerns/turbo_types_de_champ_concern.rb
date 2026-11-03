# frozen_string_literal: true

# The champs editor sends back, for the champs below an edited one, only the
# parts that display something of it.
module TurboTypesDeChampConcern
  extend ActiveSupport::Concern

  # What the champs below a type de champ display of it
  Dependencies = Data.define(:attributes, :source, :in_target_menu, :header_section_level, :prefilled_stable_ids)

  private

  def dependencies_of(type_de_champ)
    source = condition_sources([type_de_champ]).any?
    Dependencies.new(
      # store_accessor writes the options in place
      attributes: type_de_champ.attributes.slice('libelle', 'type_champ', 'options').deep_dup,
      source:,
      in_target_menu: source || Conditions::ConditionsComponent.top_level_section?(type_de_champ),
      header_section_level: (type_de_champ.header_section_level_value if type_de_champ.header_section?),
      prefilled_stable_ids: type_de_champ.referentiel? ? type_de_champ.referentiel_mapping_prefillable_stable_ids.map(&:to_s) : []
    )
  end

  def refresh_below_updated(coordinate, before:)
    refresh_below(coordinate, coordinate.siblings_starting_at(1), before:, after: dependencies_of(coordinate.type_de_champ), rerendered: [coordinate])
  end

  def refresh_below(coordinate, following, before:, after:, rerendered: [])
    with_children = following.flat_map { it.repetition? ? [it, *it.revision_type_de_champs] : [it] }
    rerendered |= champs_to_rerender(coordinate, following, with_children, before, after)
    rerendered_ids = rerendered.map(&:id)

    # a repetition renders its children, and every champ its condition block
    @morphed = rerendered
      .reject { it.parent_id.in?(rerendered_ids) }
      .map { champ_component_from(it) }
    @conditions = conditions_to_refresh(coordinate, with_children, before, after)
      .reject { it.id.in?(rerendered_ids) || it.parent_id.in?(rerendered_ids) }
      .map { conditions_component_from(it) }
  end

  def champs_to_rerender(coordinate, following, with_children, before, after)
    return following if condition_blocks_appear_or_vanish?(coordinate, before, after)

    next_header_section(following, before, after) + prefilled_champs(with_children, before, after)
  end

  # A champ shows its condition block, if only to add a condition, once there
  # is a source above it. When the edited champ becomes or stops being a source
  # with no other source above it, that block appears or vanishes below.
  def condition_blocks_appear_or_vanish?(coordinate, before, after)
    before.source != after.source && condition_sources(coordinate.condition_source_coordinates.map(&:type_de_champ)).empty?
  end

  # A header section offers its levels, and checks its own, from the closest
  # one above it: the next one alone reads the edited one.
  def next_header_section(following, before, after)
    return [] if before.header_section_level == after.header_section_level

    following.filter(&:header_section?).first(1)
  end

  # A champ prefilled by a referentiel names it
  def prefilled_champs(with_children, before, after)
    return [] if before.attributes == after.attributes

    prefilled = before.prefilled_stable_ids | after.prefilled_stable_ids
    with_children.filter { it.stable_id.to_s.in?(prefilled) }
  end

  # A condition block lists the sources and top-level sections above it in its
  # target menu, and checks its condition through the display conditions of the
  # champs it targets (Logic::DisplayConditions), which may cite the edited
  # champ even when it is no source any more. A block without condition shows
  # neither.
  def conditions_to_refresh(coordinate, candidates, before, after)
    return [] if before.attributes == after.attributes

    with_condition = candidates.filter { it.type_de_champ.condition? }
    return with_condition if before.in_target_menu || after.in_target_menu

    cited = with_condition.any? { it.type_de_champ.condition.sources.include?(coordinate.stable_id) }
    cited ? with_condition : []
  end

  def condition_sources(tdcs)
    Conditions::ConditionsComponent.sources_for(tdcs, procedure_id: @procedure.id, column_mode: !@procedure.champ_value_in_condition?)
  end

  def conditions_component_from(coordinate)
    Conditions::ChampsConditionsComponent.new(
      tdc: coordinate.type_de_champ,
      upper_tdcs: coordinate.condition_source_coordinates.map(&:type_de_champ),
      procedure: @procedure
    )
  end
end
