# frozen_string_literal: true

class EditableChamp::MultipleDropDownListComponent < EditableChamp::EditableChampBaseComponent
  include ApplicationHelper

  def dsfr_input_classname
    'fr-select'
  end

  def dsfr_champ_container
    @champ.render_as_checkboxes? ? :fieldset : :div
  end

  def react_props
    react_input_opts(
      id: @champ.focusable_input_id,
      class: 'fr-mt-1w',
      name: @form.field_name(:value, multiple: true),
      placeholder: t('views.components.multiple_combobox'),
      value: @champ.selected_options,
      items:,
      ariaLabelledbyPrefix: aria_labelledby_prefix,
      labelId: input_label_id(@champ)
    )
  end

  def items
    @champ.options_for_select
  end
end
