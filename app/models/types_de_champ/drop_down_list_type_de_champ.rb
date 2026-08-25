# frozen_string_literal: true

class TypesDeChamp::DropDownListTypeDeChamp < TypesDeChamp::DropDownBaseTypeDeChamp
  def self.category = CHOICE
  def self.option_keys = [:drop_down_other, :drop_down_options, :drop_down_mode]
  def self.column_type = :enum
  def self.simple_routable? = true
  def self.conditionable? = true

  store_accessor :options, :drop_down_other

  def prefillable? = true
  def options_for_select = options_for_select_with_other
  def any_drop_down_list? = true
  def conditionable? = !drop_down_advanced?
  def simple_routable? = !drop_down_advanced?
  def condition_value_type = :enum
  def condition_options = options_for_select_with_other
  boolean_options :drop_down_other
  def value_is_in_options?(checked_value) = options_for_select.any? { _1.last == checked_value }
  def customizable? = true

  before_validation :set_default_drop_down_options, if: :type_champ_changed?

  def typed_champ_value(champ)
    if drop_down_advanced? && champ.respond_to?(:referentiel) && champ.referentiel.present?
      path = champ.referentiel_headers&.first&.second
      champ.referentiel_item_value(path)
    else
      super
    end
  end

  def typed_champ_value_for_export(champ, path = :value)
    if drop_down_advanced? && path != :value
      champ.referentiel_item_value(path)
    else
      super
    end
  end

  def typed_champ_value_for_tag(champ, path = :value)
    if drop_down_advanced? && path != :value
      champ.referentiel_item_value(path)
    else
      super
    end
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    if drop_down_advanced?
      referentiel_columns = if referentiel.present?
        referentiel.headers_with_path.map do |(header, path)|
          options_for_select = referentiel.options_for_path(path)

          if drop_down_other?
            options_for_select << [I18n.t('shared.champs.drop_down_list.other'), Champs::DropDownListChamp::OTHER]
          end

          Columns::JSONPathColumn.new(
            procedure_id:,
            stable_id:,
            tdc_type: type_champ,
            label: "#{libelle_with_prefix(prefix)} – Référentiel #{header}",
            type: :enum,
            jsonpath: "$.referentiel.data.row.#{path}",
            displayable:,
            options_for_select:,
            mandatory: mandatory?
          )
        end
      else
        []
      end

      super + referentiel_columns
    else
      super
    end
  end

  def paths
    if drop_down_advanced? && referentiel.present?
      referentiel.headers_with_path.map do |(header, path)|
        {
          libelle: "#{libelle} (#{header})",
          description: "#{description} (#{header})",
          path:,

        }
      end
    else
      super
    end
  end

  private

  def set_default_drop_down_options
    if drop_down_options.empty?
      self.drop_down_options = ['Fromage', 'Dessert']
    end
  end

  def champ_text_value(champ)
    if champ.is_type?(TypeDeChamp.type_champs.fetch(:multiple_drop_down_list))
      TypesDeChamp::MultipleDropDownListTypeDeChamp.parse_selected_options(champ).first
    else
      super
    end
  end
end
