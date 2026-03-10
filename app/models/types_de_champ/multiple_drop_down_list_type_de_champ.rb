# frozen_string_literal: true

class TypesDeChamp::MultipleDropDownListTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def champ_value(champ)
    if drop_down_advanced? && champ.respond_to?(:referentiels) && champ.referentiels.present?
      champ.referentiels_items_user_values.join(', ')
    else
      selected_options(champ).join(', ')
    end
  end

  def champ_value_for_export(champ, path = :value)
    path == :value ? champ_value(champ).presence : super
  end

  def champ_value_for_tag(champ, path = :value)
    ChampPresentations::MultipleDropDownListPresentation.new(selected_options(champ))
  end

  def columns(procedure:, displayable: true, prefix: nil)
    if drop_down_advanced?
      path = referentiel.present? ? referentiel_path_to_get_user_value : nil
      path.present? ? [
        Columns::MultipleDropDownColumn.new(
          procedure_id: procedure.id,
          stable_id:,
          tdc_type: type_champ,
          label: libelle,
          type: :enum,
          jsonpath: "$.referentiels.*.data.row.#{path}",
          displayable:,
          options_for_select: referentiel.options_for_path(path),
          mandatory: mandatory?
        ),
      ] : []
    else
      super
    end
  end

  def champ_blank?(champ) = selected_options(champ).blank?

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

  def referentiel_path_to_get_user_value
    referentiel.headers_with_path.first.second
  end

  private

  def selected_options(champ)
    self.class.parse_selected_options(champ)
  end
end
