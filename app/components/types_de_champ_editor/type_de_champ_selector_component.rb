# frozen_string_literal: true

class TypesDeChampEditor::TypeDeChampSelectorComponent < ApplicationComponent
  attr_reader :coordinate

  def initialize(coordinate:)
    @coordinate = coordinate
  end

  private

  delegate :type_de_champ, :revision, :procedure, to: :coordinate

  def current_type_champ
    type_de_champ.type_champ
  end

  def current_type_label
    t(current_type_champ, scope: "activerecord.attributes.type_de_champ.type_champs")
  end

  def current_type_icon
    TypeDeChamp::TYPE_DE_CHAMP_TO_ICON.fetch(current_type_champ.to_sym)
  end

  def disabled?
    coordinate.used_by_routing_rules? || coordinate.used_by_ineligibilite_rules? || accepted_type_champs.size == 1
  end

  def grouped_types
    cat_scope = "activerecord.attributes.type_de_champ.categorie"
    tdc_scope = "activerecord.attributes.type_de_champ.type_champs"

    TypeDeChamp::TYPE_DE_CHAMP_TO_CATEGORIE.keys.map(&:to_s)
      .filter { filter_type_champ(_1) }
      .filter { filter_featured_type_champ(_1) }
      .filter { filter_block_type_champ(_1) }
      .filter { filter_public_or_private_only_type_champ(_1) }
      .group_by { TypeDeChamp::TYPE_DE_CHAMP_TO_CATEGORIE.fetch(_1.to_sym) }
      .sort_by { |k, _v| TypeDeChamp::CATEGORIES.find_index(k) }
      .map do |cat, tdcs|
        {
          key: cat,
          label: t(cat, scope: cat_scope),
          types: tdcs.map do |tdc|
            {
              value: tdc,
              label: t(tdc, scope: tdc_scope),
              icon: TypeDeChamp::TYPE_DE_CHAMP_TO_ICON.fetch(tdc.to_sym),
              disabled: !accepted_type_champs.include?(tdc),
              selected: tdc == current_type_champ,
            }
          end,
        }
      end
  end

  ACCEPTED_TYPES = Columns::ChampColumn::CAST.keys
    .group_by { |(from)| from.to_s }
    .transform_values { |pairs| pairs.map { |(_, to)| to.to_s } }

  def accepted_type_champs
    @accepted_type_champs ||= if published_type_champ.present?
      ([published_type_champ] + ACCEPTED_TYPES.fetch(published_type_champ, [])).uniq
    else
      TypeDeChamp.type_champs.keys
    end
  end

  def published_type_champ
    @published_type_champ ||= procedure.published_revision&.types_de_champ&.find { _1.stable_id == type_de_champ.stable_id }&.type_champ
  end

  EXCLUDE_FROM_BLOCK = [
    TypeDeChamp.type_champs.fetch(:repetition),
    TypeDeChamp.type_champs.fetch(:quotient_familial),
  ]

  def filter_block_type_champ(type_champ)
    !coordinate.child? || !EXCLUDE_FROM_BLOCK.include?(type_champ)
  end

  def filter_public_or_private_only_type_champ(type_champ)
    if coordinate.private?
      !TypeDeChamp::PUBLIC_ONLY_TYPES.include?(type_champ)
    else
      !TypeDeChamp::PRIVATE_ONLY_TYPES.include?(type_champ)
    end
  end

  def filter_featured_type_champ(type_champ)
    feature_name = TypeDeChamp::FEATURE_FLAGS[type_champ.to_sym]
    feature_name.blank? || procedure.feature_enabled?(feature_name)
  end

  def filter_type_champ(type_champ)
    if type_champ == TypeDeChamp.type_champs.fetch(:titre_identite)
      return type_de_champ.titre_identite?
    end

    case type_champ
    when TypeDeChamp.type_champs.fetch(:number)
      has_legacy_number?
    when TypeDeChamp.type_champs.fetch(:cnaf)
      procedure.cnaf_enabled?
    when TypeDeChamp.type_champs.fetch(:dgfip)
      procedure.dgfip_enabled?
    when TypeDeChamp.type_champs.fetch(:pole_emploi)
      procedure.pole_emploi_enabled?
    when TypeDeChamp.type_champs.fetch(:mesri)
      procedure.mesri_enabled?
    else
      true
    end
  end

  def has_legacy_number?
    @has_legacy_number ||= revision.types_de_champ.any?(&:number?)
  end
end
