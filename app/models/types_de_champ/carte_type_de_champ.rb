# frozen_string_literal: true

class TypesDeChamp::CarteTypeDeChamp < TypesDeChamp::TypeDeChampBase
  LAYERS = [
    :unesco,
    :arretes_protection,
    :conservatoire_littoral,
    :reserves_chasse_faune_sauvage,
    :reserves_biologiques,
    :reserves_naturelles,
    :natura_2000,
    :zones_humides,
    :znieff,
    :cadastres,
    :rpg,
  ]

  def estimated_fill_duration
    FILL_DURATION_LONG
  end

  def filled_champ_value_for_tag(champ, path = :value)
    return nil if path != :value
    return '' if champ.geo_areas.blank?
    ChampPresentations::CartePresentation.new(champ.geo_areas)
  end

  def filled_champ_value_for_api(champ, version: 2)
    nil
  end

  def filled_champ_value_for_export(champ, path = :value)
    champ.geo_areas.map(&:label).join("\n")
  end

  def champ_value_blank?(champ) = champ.geo_areas.blank?

  def canonical_column(procedure_id:, displayable: true, prefix: nil)
    Columns::GeoJSONColumn.new(
      procedure_id:,
      stable_id:,
      tdc_type: type_champ,
      label: libelle_with_prefix(prefix),
      type: TypeDeChamp.column_type(type_champ),
      displayable: false,
      filterable: false,
      mandatory: mandatory?
    )
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    []
  end
end
