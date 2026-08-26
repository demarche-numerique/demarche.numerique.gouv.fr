# frozen_string_literal: true

class TypesDeChamp::Carte < TypeDeChamp
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

  # `cadastres` and `rpg` are backed by the same map layer ids: enabling both
  # breaks the map, so they are mutually exclusive.
  PARCELLE_LAYERS = [:cadastres, :rpg]

  before_validation :ensure_exclusive_parcelle_layer

  store_accessor :options, :cadastres

  def self.category = REFERENTIEL_EXTERNE
  def self.option_keys = LAYERS
  def self.column_type = :geojson

  def refresh_after_update? = false

  def layer_enabled?(layer)
    ActiveModel::Type::Boolean.new.cast(options&.dig(layer)) || false
  end

  def carte_optional_layers
    LAYERS.filter_map do |layer|
      layer_enabled?(layer) ? layer : nil
    end.sort
  end

  def editable_options=(options)
    self.options.merge!(options)
  end

  def editable_options
    layers = LAYERS.map do |layer|
      disabled = case layer
      when :cadastres
        layer_enabled?(:rpg)
      when :rpg
        layer_enabled?(:cadastres)
      else
        false
      end
      [layer, layer_enabled?(layer), disabled]
    end
    layers.each_slice((layers.size / 2.0).round).to_a
  end

  def estimated_fill_duration(revision)
    FILL_DURATION_LONG
  end

  def typed_champ_value_for_tag(champ, path = :value)
    return nil if path != :value
    return '' if champ.geo_areas.blank?
    ChampPresentations::CartePresentation.new(champ.geo_areas)
  end

  def typed_champ_value_for_api(champ, version: 2)
    nil
  end

  def typed_champ_value_for_export(champ, path = :value)
    champ.geo_areas.map(&:label).join("\n")
  end

  def typed_champ_blank?(champ) = champ.geo_areas.blank?

  def canonical_column(procedure_id:, displayable: true, prefix: nil)
    Columns::GeoJSONColumn.new(
      procedure_id:,
      stable_id:,
      tdc_type: type_champ,
      label: libelle_with_prefix(prefix),
      type: self.class.column_type,
      displayable: false,
      filterable: false,
      mandatory: mandatory?
    )
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    []
  end

  private

  # The editor disables one parcelle checkbox as soon as the other is checked, but a
  # stale form (or the API) can still send both: keep the layer that was just enabled
  # and disable the other one, so the map keeps working.
  def ensure_exclusive_parcelle_layer
    return if PARCELLE_LAYERS.any? { !layer_enabled?(it) }

    previously_enabled = PARCELLE_LAYERS.filter { layer_enabled_before_change?(it) }
    kept = (PARCELLE_LAYERS - previously_enabled).first || PARCELLE_LAYERS.first

    self.options = options.merge((PARCELLE_LAYERS - [kept]).index_with { false })
  end

  def layer_enabled_before_change?(layer)
    options_was.present? && options_was[layer].present? && options_was[layer] != '0'
  end
end
