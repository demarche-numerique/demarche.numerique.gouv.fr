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
    @source_tdcs ||= draft_revision.type_de_champ(type_de_champ.stable_id).prefill_targets
  end

  def prefill_stable_id_tag(jsonpath, mapping_opts)
    target_tdcs = tdc_targets(mapping_opts)
    selected_value = lookup_existing_value(jsonpath, "prefill_stable_id")

    select_tag(
      attribute_name(jsonpath, "prefill_stable_id"),
      grouped_options_for_select(target_tdcs, selected_value),
      class: "fr-select"
    )
  end

  private

  def tdc_targets(mapping_element)
    allowed_types_for_mapping(mapping_element[:type])
      .then { |allowed_types| filter_incompatible_tdcs(allowed_types) }
      .then { |filtered_tdcs| group_tdcs_by_visibility(filtered_tdcs) }
      .compact_blank
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

  def render?
    referentiel_mapping_prefillable.any?
  end
end
