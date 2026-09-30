# frozen_string_literal: true

class EditableChamp::CarteComponent < EditableChamp::EditableChampBaseComponent
  include ApplicationHelper
  def dsfr_champ_container
    :fieldset
  end

  def address_aria_labelledby_prefix
    "#{aria_labelledby_prefix} #{champ_fieldset_legend_id(@champ)}"
  end
end
