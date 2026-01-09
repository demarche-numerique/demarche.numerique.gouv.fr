# frozen_string_literal: true

class Referentiels::MappingFormComponent < Referentiels::MappingFormBase
  TYPES = [:string, :decimal_number, :integer_number, :boolean, :date, :datetime, :array].index_by(&:itself).freeze

  def last_request_keys
    JSONPathUtil.hash_to_jsonpath(referentiel.last_response_body)
      .sort
      .to_h
  end

  def back_url
    if referentiel.autocomplete?
      autocomplete_configuration_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel.id)
    else
      edit_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel.id)
    end
  end

  def cast_tag(jsonpath, value)
    select_tag(
      attribute_name(jsonpath, "type"),
      options_for_select(self.class::TYPES.values.map { [t("utils.#{it}"), it] }, lookup_existing_value(jsonpath, "type") || value_to_type(value, jsonpath)),
      class: "fr-select"
    )
  end

  def prefill_tag(jsonpath)
    tag.div(class: "fr-checkbox-group") do
      safe_join([
        hidden_field_tag(attribute_name(jsonpath, "prefill"), "0"),
        check_box_tag(attribute_name(jsonpath, "prefill"), "1", lookup_existing_value(jsonpath, "prefill") == "1", class: "fr-checkbox", id: jsonpath.parameterize, data: { "action": "change->referentiel-mapping#onCheckboxChange" }, aria: { labelledby: label_check_prefill(jsonpath) }),
        tag.label(for: jsonpath.parameterize, class: "fr-label", aria: { hidden: true }) { sanitize("&nbsp;") },
      ])
    end
  end

  def enabled_libelle_tag(jsonpath)
    text_field_tag(
      attribute_name(jsonpath, "libelle"),
      lookup_existing_value(jsonpath, "libelle") || jsonpath,
      libelle_field_options(jsonpath)
    )
  end

  def disabled_libelle_tag(jsonpath)
    safe_join([
      tag.p("Libellé du champ du formulaire"),
      tag.p("(à définir à l’étape suivante)", class: 'fr-text--sm fr-text-action-high--blue-france'),
    ])
  end

  def label_check_prefill(jsonpath)
    "use-for-prefill-#{jsonpath.parameterize}"
  end

  private

  def disabled?(jsonpath)
    lookup_existing_value(jsonpath, "prefill") == "1"
  end

  def value_to_type(value, jsonpath)
    if DateDetectionUtils.should_suggest_timestamp_mapping?(value, jsonpath)
      self.class::TYPES[:datetime]
    elsif value.is_a?(String) && DateDetectionUtils.parsable_iso8601_date?(value)
      self.class::TYPES[:date]
    elsif value.is_a?(String) && DateDetectionUtils.parsable_iso8601_datetime?(value)
      self.class::TYPES[:datetime]
    elsif ReferentielMappingUtils.array_of_supported_simple_types?(value)
      self.class::TYPES[:array]
    elsif value.is_a?(Float)
      self.class::TYPES[:decimal_number]
    elsif value.is_a?(Integer)
      self.class::TYPES[:integer_number]
    elsif value.is_a?(TrueClass) || value.is_a?(FalseClass)
      self.class::TYPES[:boolean]
    else
      TYPES.fetch(:string)
    end
  end

  def libelle_field_options(jsonpath)
    {
      class: 'fr-input',
      data: {
        "referentiel-mapping-target": "input",
        'referentiel-mapping-enabled-value': disabled?(jsonpath),
      },
    }
  end
end
