# frozen_string_literal: true

# The "Type de champ" menu of a field in the procedure editor: the types
# listed where the field sits, grouped by category, with the ones the revision
# refuses greyed out (RevisionEditConcern#accepted_type_champs).
class TypesDeChampEditor::TypeDeChampSelectorComponent < ApplicationComponent
  def initialize(type_de_champ:, form:)
    @type_de_champ = type_de_champ
    @form = form
  end

  private

  attr_reader :type_de_champ, :form

  delegate :revision, to: :type_de_champ
  delegate :procedure, to: :revision

  def trigger_id = dom_id(type_de_champ, :type_champ)
  def label_id = dom_id(type_de_champ, :type_champ_label)

  def select_props
    {
      name: form.field_name(:type_champ),
      value: type_de_champ.class.menu_value,
      sections:,
      disabledKeys: disabled_keys,
      isDisabled: disabled?,
      triggerId: trigger_id,
      labelId: label_id,
    }
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
            { value: klass.menu_value, label: t(klass.menu_value, scope: tdc_scope, app_name: APPLICATION_NAME), icon: klass.icon }
          end.uniq,
        }
      end
  end

  def disabled_keys
    available_types
      .reject { accepted_type_champs.include?(it.sti_name) }
      .map(&:menu_value)
      .uniq
  end

  def available_types
    @available_types ||= TypeDeChamp.type_champ_classes
      .filter(&method(:filter_featured_type_champ))
      .filter(&method(:filter_block_type_champ))
      .filter(&method(:filter_public_or_private_only_type_champ))
  end

  # what the revision lets it become: the menu greys out the rest
  def accepted_type_champs
    @accepted_type_champs ||= revision.accepted_type_champs(type_de_champ)
  end

  def disabled?
    type_de_champ.type_champ_locked? || accepted_type_champs.size == 1
  end

  def filter_block_type_champ(klass)
    !type_de_champ.in_repetition? || klass.allowed_in_repetition?
  end

  def filter_public_or_private_only_type_champ(klass)
    type_de_champ.private? ? !klass.public_only? : !klass.private_only?
  end

  def filter_featured_type_champ(klass)
    klass.feature_flag.nil? || procedure.feature_enabled?(klass.feature_flag)
  end
end
