# frozen_string_literal: true

class TypesDeChamp::MultipleDropDownListTypeDeChamp < TypesDeChamp::DropDownBaseTypeDeChamp
  def self.category = CHOICE
  def self.option_keys = [:drop_down_options, :drop_down_mode]
  def self.column_type = :enums
  def self.conditionable? = true

  store_accessor :options, :drop_down_mode

  def prefillable? = true
  def drop_down_advanced? = drop_down_mode == 'advanced'
  def options_for_select = options_for_select_with_other
  def conditionable? = !drop_down_advanced?
  def condition_value_type = :enums
  def condition_options = options_for_select_with_other
  def customizable? = true

  before_validation :set_default_drop_down_options, if: :type_champ_changed?

  def typed_champ_value(champ)
    if drop_down_advanced? && champ.respond_to?(:referentiels) && champ.referentiels.present?
      champ.referentiels_items_user_values.join(', ')
    else
      selected_options(champ).join(', ')
    end
  end

  def typed_champ_value_for_export(champ, path = :value)
    path == :value ? typed_champ_value(champ).presence : super
  end

  def typed_champ_value_for_tag(champ, path = :value)
    ChampPresentations::MultipleDropDownListPresentation.new(selected_options(champ))
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    if drop_down_advanced?
      referentiel.present? ? referentiel.headers_with_path.map do |(header, path)|
        Columns::MultipleDropDownColumn.new(
          procedure_id:,
          stable_id:,
          tdc_type: type_champ,
          label: "#{libelle_with_prefix(prefix)} – Référentiel #{header}",
          type: :enum,
          jsonpath: "$.referentiels.*.data.row.#{path}",
          displayable:,
          options_for_select: referentiel.options_for_path(path),
          mandatory: mandatory?
        )
      end : []
    else
      super
    end
  end

  def typed_champ_blank?(champ) = selected_options(champ).blank?
  def block_level_tag? = true

  def self.parse_selected_options(champ)
    return [] if champ.value.blank?

    if champ.is_type?(TypeDeChamp.type_champs.fetch(:drop_down_list))
      [champ.value]
    else
      JSON.parse(champ.value)
    end
  rescue JSON::ParserError
    []
  end

  private

  def selected_options(champ)
    self.class.parse_selected_options(champ)
  end

  def set_default_drop_down_options
    if drop_down_options.empty?
      self.drop_down_options = ['Fromage', 'Dessert']
    end
  end
end
