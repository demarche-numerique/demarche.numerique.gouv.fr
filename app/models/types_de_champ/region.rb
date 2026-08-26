# frozen_string_literal: true

class TypesDeChamp::Region < TypesDeChamp::Text
  def self.category = LOCALISATION
  def self.column_type = :enum
  def self.simple_routable? = true
  def self.conditionable? = true

  def options_for_select = APIGeoService.region_options
  def condition_value_type = :enum
  def condition_options = APIGeoService.region_options

  include AddressableColumnConcern

  def columns(procedure_id:, displayable: true, prefix: nil)
    addressable_columns(procedure_id:, displayable:, prefix:, only: [:region_code])
      .concat(legacy_columns(procedure_id:, prefix:))
  end

  def typed_champ_value(champ)
    champ.name
  end

  def typed_champ_value_for_export(champ, path = :value)
    case path
    when :value
      typed_champ_value(champ)
    when :code
      champ.code
    end
  end

  def typed_champ_value_for_tag(champ, path = :value)
    case path
    when :value
      typed_champ_value(champ)
    when :code
      champ.code
    end
  end

  private

  # ChampColumn par défaut conservé pour rester résolvable par les ProcedurePresentation /
  # exports / colonnes graphql persistées avant la bascule sur AddressableColumnConcern.
  def legacy_columns(procedure_id:, prefix:)
    [
      Columns::ChampColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: libelle_with_prefix(prefix),
        type: :enum,
        displayable: false,
        filterable: false,
        options_for_select:,
        mandatory: mandatory?
      ),
    ]
  end

  def paths
    paths = super
    paths.push({
      libelle: "#{libelle} (Code)",
      description: "#{description} (Code)",
      path: :code,

    })
    paths
  end
end
