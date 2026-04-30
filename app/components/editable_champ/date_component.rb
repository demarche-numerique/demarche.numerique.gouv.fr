# frozen_string_literal: true

class EditableChamp::DateComponent < EditableChamp::EditableChampBaseComponent
  def dsfr_input_classname
    'fr-input'
  end

  def min_date
    if @champ.birthdate?
      DateLimitValidator::BIRTHDATE_MIN
    elsif @champ.range_date? && @champ.start_date.present?
      @champ.start_date
    end
  end

  def max_date
    if @champ.birthdate?
      Date.today
    elsif @champ.date_in_past?
      Date.yesterday
    elsif @champ.range_date? && @champ.end_date.present?
      @champ.end_date
    end
  end
end
