# frozen_string_literal: true

class Referentiels::ReferentielPrefillComponent < Referentiels::MappingFormBase
  delegate :referentiel_mapping,
           :referentiel_mapping_prefillable,
           to: :type_de_champ

  delegate :draft_revision, to: :procedure

  MAPPING_TYPE_TO_TYPE_DE_CHAMP = {
    Referentiels::MappingFormComponent::TYPES[:string] => %w[text textarea engagement_juridique dossier_link email phone iban siret drop_down_list formatted referentiel civilite address pre_rempli],
    Referentiels::MappingFormComponent::TYPES[:decimal_number] => %w[decimal_number],
    Referentiels::MappingFormComponent::TYPES[:integer_number] => %w[integer_number referentiel],
    Referentiels::MappingFormComponent::TYPES[:boolean] => %w[checkbox yes_no],
    Referentiels::MappingFormComponent::TYPES[:date] => %w[date],
    Referentiels::MappingFormComponent::TYPES[:datetime] => %w[datetime],
    Referentiels::MappingFormComponent::TYPES[:array] => %w[multiple_drop_down_list],
  }.freeze

  def public_fields_group
    t(".public_fields_group")
  end

  def private_annotations_group
    t(".private_annotations_group")
  end

  def source_tdcs
    @source_tdcs ||= collect_public_tdcs + collect_private_tdcs
  end

  def prefill_stable_id_tag(jsonpath, mapping_opts)
    target_tdcs = tdc_targets(mapping_opts)
    selected_value = lookup_existing_value(jsonpath, "prefill_stable_id")

    select_tag(
      attribute_name(jsonpath, "prefill_stable_id"),
      build_select_options(target_tdcs, selected_value),
      class: "fr-select"
    )
  end

  private

  def build_select_options(target_tdcs, selected_value)
    if type_de_champ.public?
      grouped_options_for_select(target_tdcs, selected_value)
    else
      options_for_select(target_tdcs, selected_value)
    end
  end

  def tdc_targets(mapping_element)
    allowed_types_for_mapping(mapping_element[:type])
      .then { |allowed_types| filter_incompatible_tdcs(allowed_types) }
      .then { |filtered_tdcs| group_tdcs_by_visibility(filtered_tdcs) }
      .then { |grouped_tdcs| select_grouped_tdcs(grouped_tdcs) }
  end

  def allowed_types_for_mapping(mapping_type)
    MAPPING_TYPE_TO_TYPE_DE_CHAMP[mapping_type.to_sym] || []
  end

  def filter_incompatible_tdcs(allowed_types)
    source_tdcs.reject { current_field?(it) || incompatible_type?(it, allowed_types) }
  end

  def current_field?(tdc)
    tdc.stable_id == type_de_champ.stable_id
  end

  def incompatible_type?(tdc, allowed_types)
    allowed_types.exclude?(tdc.type_champ)
  end

  def group_tdcs_by_visibility(tdcs)
    tdcs.each_with_object(empty_groups) do |tdc, grouped_tdcs|
      group = visibility_group_for(tdc)
      grouped_tdcs[group] << tdc_option_for(tdc)
    end
  end

  def empty_groups
    { public_fields_group => [], private_annotations_group => [] }
  end

  def visibility_group_for(tdc)
    if tdc.public?
      public_fields_group
    else
      private_annotations_group
    end
  end

  def tdc_option_for(tdc)
    [tdc.libelle_with_parent, tdc.stable_id]
  end

  def select_grouped_tdcs(grouped_tdcs)
    if type_de_champ.public?
      grouped_tdcs.compact_blank
    else
      grouped_tdcs[private_annotations_group]
    end
  end

  # Champs prefillable : uniquement ceux situés en aval du référentiel courant.
  # Dans une répétition, on reste dans la ligne courante (les frères en aval) ;
  # sinon, tout ce qui suit dans l'ordre du formulaire (le flatten respecte les positions).
  def tdcs_after_current(tdcs)
    current = draft_revision.find_type_de_champ_by_stable_id(type_de_champ.stable_id)
    scope = current.in_repetition? ? current.enclosing_repetition.flat_children : tdcs
    scope.drop(scope.index { it.stable_id == current.stable_id } + 1)
  end

  def collect_public_tdcs
    if type_de_champ.public?
      tdcs_after_current(draft_revision.types_de_champ.filter(&:public?))
    else
      []
    end
  end

  def collect_private_tdcs
    private_tdcs = draft_revision.types_de_champ.filter(&:private?)
    if type_de_champ.public?
      private_tdcs
    else
      tdcs_after_current(private_tdcs)
    end
  end

  def render?
    referentiel_mapping_prefillable.any?
  end
end
