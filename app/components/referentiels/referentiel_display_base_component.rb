# frozen_string_literal: true

class Referentiels::ReferentielDisplayBaseComponent < ApplicationComponent
  delegate :type_de_champ, to: :@champ
  delegate :safe_referentiel_mapping,
           :referentiel_mapping_displayable_for_usager,
           :referentiel_mapping_displayable_for_instructeur,
           to: :type_de_champ
  attr_reader :champ

  def initialize(champ:)
    @champ = champ
  end

  def render?
    type_de_champ.referentiel? && data.present?
  end

  private

  def safe_value_json
    @safe_value_json ||= Hash(@champ.value_json).with_indifferent_access
  end

  def libelle(jsonpath)
    safe_referentiel_mapping[jsonpath]&.dig(:libelle).presence || jsonpath
  end

  def format(jsonpath, value)
    mapping_type = safe_referentiel_mapping[jsonpath]&.dig(:type) || Referentiels::MappingFormComponent::TYPES[:string]
    case [mapping_type&.to_sym, value]
    in [:date, value]
      I18n.l(Date.parse(DateDetectionUtils.convert_to_iso8601_date(value)), format: :short) rescue nil
    in [:datetime, value]
      I18n.l(DateTime.parse(DateDetectionUtils.convert_to_iso8601_datetime(value)), format: :long_with_time) rescue nil
    in [:boolean, TrueClass => value]
      t('utils.yes')
    in [:boolean, FalseClass => value]
      t('utils.no')
    in [:array, Array => value] if ReferentielMappingUtils.array_of_supported_simple_types?(value)
      Array(value).compact.join(", ")
    in [:string | :decimal_number | :integer_number, String | Float | Integer => value]
      value
    else
      nil
    end
  end
end
