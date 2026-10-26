# frozen_string_literal: true

# The "Type de champ" menu of a field in the procedure editor: the types the
# field may take, grouped by category, with the types the published revision
# cannot be converted to greyed out.
class TypesDeChampEditor::TypeDeChampSelectorComponent < ApplicationComponent
  def initialize(coordinate:, form:)
    @coordinate = coordinate
    @form = form
  end

  private

  attr_reader :coordinate, :form

  delegate :type_de_champ, :revision, :procedure, to: :coordinate

  def trigger_id = dom_id(type_de_champ, :type_champ)
  def label_id = dom_id(type_de_champ, :type_champ_label)

  def select_props
    {
      name: form.field_name(:type_champ),
      value:,
      sections:,
      disabledKeys: disabled_keys,
      isDisabled: disabled?,
      triggerId: trigger_id,
      labelId: label_id,
    }
  end

  def value
    return 'numeric' if type_de_champ.type_champ == 'integer_number' || type_de_champ.type_champ == 'decimal_number'
    type_de_champ.type_champ
  end

  def sections
    cat_scope = "activerecord.attributes.type_de_champ.categorie"
    tdc_scope = "activerecord.attributes.type_de_champ.type_champs"
    available_types
      .sort_by(&:menu_position)
      .group_by(&:category)
      .map do |category, klasses|
        {
          id: category,
          label: t(category, scope: cat_scope),
          items: klasses.map do |klass|
            if klass == TypesDeChamp::IntegerNumberTypeDeChamp || klass == TypesDeChamp::DecimalNumberTypeDeChamp
              { value: 'numeric', label: t('numeric', scope: tdc_scope, app_name: APPLICATION_NAME), icon: klass.icon }
            else
              { value: klass.sti_name, label: t(klass.sti_name, scope: tdc_scope, app_name: APPLICATION_NAME), icon: klass.icon }
            end
          end.uniq,
        }
      end
  end

  def disabled_keys
    disabled_keys = available_types.map(&:sti_name) - accepted_type_champs
    if disabled_keys.include?('integer_number') || disabled_keys.include?('decimal_number')
      disabled_keys.push('numeric')
    end
    disabled_keys
  end

  def available_types
    @available_types ||= TypeDeChamp.type_champ_classes
      .filter(&method(:filter_featured_type_champ))
      .filter(&method(:filter_block_type_champ))
      .filter(&method(:filter_public_or_private_only_type_champ))
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
    @published_type_champ ||= procedure.published_revision&.type_de_champs&.find { _1.stable_id == type_de_champ.stable_id }&.type_champ
  end

  def disabled?
    coordinate.used_by_routing_rules? || coordinate.used_by_ineligibilite_rules? || accepted_type_champs.size == 1
  end

  def filter_block_type_champ(klass)
    !coordinate.child? || klass.allowed_in_repetition?
  end

  def filter_public_or_private_only_type_champ(klass)
    coordinate.private? ? !klass.public_only? : !klass.private_only?
  end

  def filter_featured_type_champ(klass)
    klass.feature_flag.nil? || procedure.feature_enabled?(klass.feature_flag)
  end
end
