# frozen_string_literal: true

# After an edit, the champs editor sends back, of the champs below the edited
# one, only what shows something of it.
module TurboTypesDeChampConcern
  extend ActiveSupport::Concern

  # What the champs below a type de champ show of it. In the target menu of
  # their conditions: the options it renders as a source, the libelle it
  # groups them under as a top-level section.
  Footprint = Data.define(:attributes, :sources, :section, :header_section_level, :prefilled_stable_ids)

  NO_FOOTPRINT = Footprint.new(attributes: {}, sources: [], section: nil, header_section_level: nil, prefilled_stable_ids: [])

  private

  def footprint_of(type_de_champ)
    Footprint.new(
      # store_accessor writes the options in place
      attributes: type_de_champ.attributes.slice('libelle', 'type_champ', 'options').deep_dup,
      sources: condition_sources([type_de_champ]).map { |label, source| [label, source.to_json] },
      section: (type_de_champ.libelle if Conditions::ConditionsComponent.top_level_section?(type_de_champ)),
      header_section_level: (type_de_champ.header_section_level_value if type_de_champ.header_section?),
      prefilled_stable_ids: type_de_champ.referentiel? ? type_de_champ.referentiel_mapping_prefillable_stable_ids.map(&:to_s) : []
    )
  end

  # The champs below to send back whole; the condition blocks to replace go in
  # @conditions.
  def refresh_below(type_de_champ, following, before:, after:)
    return following if condition_blocks_appear_or_vanish?(type_de_champ, following, before, after)

    below = following.flat_map { it.repetition? ? [it, *it.flat_children] : [it] }
    whole = next_header_section(following, before, after) + prefilled(below, before, after)
    @conditions = conditions_below(type_de_champ, below, before, after).excluding(whole).map { conditions_component_from(it) }
    whole
  end

  # A champ shows its condition block, if only to add a condition, once a
  # source sits above it. When the edited champ becomes or stops being one,
  # with no other above it, that block appears or vanishes below.
  def condition_blocks_appear_or_vanish?(type_de_champ, following, before, after)
    return false if following.empty? || before.sources.present? == after.sources.present?

    # what the first one below sees, the edited champ aside: what is above it
    above = following.first.condition_source_type_de_champs.reject { it.stable_id == type_de_champ.stable_id }
    condition_sources(above).empty?
  end

  # A header section offers its levels from the closest one above it
  def next_header_section(following, before, after)
    return [] if before.header_section_level == after.header_section_level

    [following.find(&:header_section?)].compact
  end

  # A champ prefilled by a referentiel names it
  def prefilled(below, before, after)
    return [] if before.attributes == after.attributes

    stable_ids = before.prefilled_stable_ids | after.prefilled_stable_ids
    below.filter { it.stable_id.to_s.in?(stable_ids) }
  end

  # A condition block lists the champs it may target in its menu, and reads
  # the ones its condition targets, with the champs these are displayed under
  # (Logic::DisplayConditions). A block without condition shows neither.
  def conditions_below(type_de_champ, below, before, after)
    with_condition = below.filter(&:condition?)
    return with_condition if [before.sources, before.section] != [after.sources, after.section]
    return [] if before.attributes == after.attributes

    display_conditions = Logic::DisplayConditions.new(draft.type_de_champs)
    with_condition.filter { type_de_champ.stable_id.in?(display_conditions.read_sources(it.condition)) }
  end

  def condition_sources(type_de_champs)
    Conditions::ConditionsComponent.sources_for(type_de_champs, procedure_id: @procedure.id, column_mode: !@procedure.champ_value_in_condition?)
  end

  def conditions_component_from(type_de_champ)
    Conditions::ChampsConditionsComponent.new(tdc: type_de_champ, upper_tdcs: type_de_champ.condition_source_type_de_champs, procedure: @procedure)
  end
end
