# frozen_string_literal: true

# After an edit, the champs editor sends back, of the champs below the edited
# one, only what shows something of it.
module TurboTypesDeChampConcern
  extend ActiveSupport::Concern

  # The attributes a champ below can show of the edited one
  SHOWN_ATTRIBUTES = ['libelle', 'type_champ', 'options'].freeze

  # What the champs below show of a type de champ that its changes do not tell:
  # its entries in the target menu of their conditions, as a source or as the
  # libelle of a top-level section, and the champs it prefills, which a type
  # change empties.
  Footprint = Data.define(:sources, :section, :prefilled_stable_ids)

  private

  def footprint_of(type_de_champ)
    Footprint.new(
      sources: type_de_champ.condition_sources(@procedure),
      section: (type_de_champ.libelle if type_de_champ.top_level_section?),
      prefilled_stable_ids: type_de_champ.referentiel? ? type_de_champ.referentiel_mapping_prefillable_stable_ids.map(&:to_s) : []
    )
  end

  # The champs below to send back whole; the condition blocks to replace go in
  # @conditions. changes: as saved_changes.
  def refresh_below(type_de_champ, following, changes:, before:, after:)
    return following if condition_blocks_appear_or_vanish?(type_de_champ, following, before, after)

    shown_changes = changes.slice(*SHOWN_ATTRIBUTES)
    below = following.flat_map { it.repetition? ? [it, *it.flat_children] : [it] }
    whole = next_header_section(type_de_champ, following, shown_changes) + prefilled(below, shown_changes, before, after)
    @conditions = conditions_below(type_de_champ, below, shown_changes, before, after).excluding(whole).map { conditions_component_from(it) }
    whole
  end

  # A champ shows its condition block, if only to add a condition, once a
  # source sits above it. When the edited champ becomes or stops being one,
  # with no other above it, that block appears or vanishes below.
  def condition_blocks_appear_or_vanish?(type_de_champ, following, before, after)
    return false if following.empty? || before.sources.present? == after.sources.present?

    # what the first one below sees, the edited champ aside: what is above it
    above = following.first.condition_source_type_de_champs.reject { it.stable_id == type_de_champ.stable_id }
    above.all? { it.condition_sources(@procedure).empty? }
  end

  # A header section offers its levels from the closest one above it
  def next_header_section(type_de_champ, following, changes)
    level_changed = changes.fetch('type_champ', []).include?('header_section') || (type_de_champ.header_section? && changes.key?('options'))
    return [] if !level_changed

    [following.find(&:header_section?)].compact
  end

  # A champ prefilled by a referentiel names it
  def prefilled(below, changes, before, after)
    return [] if !changes.key?('libelle') && !changes.key?('type_champ')

    stable_ids = before.prefilled_stable_ids | after.prefilled_stable_ids
    below.filter { it.stable_id.to_s.in?(stable_ids) }
  end

  # A condition block lists the champs it may target in its menu, and reads
  # the ones its condition targets, with the champs these are displayed under
  # (Logic::DisplayConditions). A block without condition shows neither.
  def conditions_below(type_de_champ, below, changes, before, after)
    with_condition = below.filter(&:condition?)
    return with_condition if [before.sources, before.section] != [after.sources, after.section]
    return [] if changes.empty?

    display_conditions = Logic::DisplayConditions.new(draft.type_de_champs)
    with_condition.filter { type_de_champ.stable_id.in?(display_conditions.read_sources(it.condition)) }
  end

  def conditions_component_from(type_de_champ)
    Conditions::ChampsConditionsComponent.new(tdc: type_de_champ, upper_tdcs: type_de_champ.condition_source_type_de_champs, procedure: @procedure)
  end
end
