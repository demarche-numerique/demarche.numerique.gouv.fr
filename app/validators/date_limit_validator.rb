# frozen_string_literal: true

class DateLimitValidator < ActiveModel::Validator
  BIRTHDATE_MIN = Date.new(1900, 1, 1)

  def validate(champ)
    date = safe_date(champ.value)
    return if date.nil?

    if champ.type_de_champ.birthdate?
      validate_birthdate(champ, date)
    else
      validate_in_past(champ, date) if champ.type_de_champ.date_in_past?
      validate_in_range(champ, date) if champ.type_de_champ.range_date?
    end
  end

  private

  def validate_birthdate(champ, date)
    if !(BIRTHDATE_MIN..Date.today).cover?(date)
      # i18n-tasks-use t('errors.messages.invalid_birthdate')
      champ.errors.add(:value, :invalid_birthdate)
    end
  end

  def validate_in_past(champ, date)
    if date >= Date.today
      # i18n-tasks-use t('errors.messages.date_in_past')
      champ.errors.add(:value, :date_in_past)
    end
  end

  def validate_in_range(champ, date)
    start_date, end_date = [champ.start_date, champ.end_date].map { safe_date(it) }

    if start_date.present? && end_date.present? && not_in_range(start_date, end_date, date)
      # i18n-tasks-use t('errors.messages.not_in_range_date')
      champ.errors.add(:value, :not_in_range_date, start_date: I18n.l(start_date), end_date: I18n.l(end_date))
    elsif start_date.present? && date < start_date
      # i18n-tasks-use t('errors.messages.limit_start_date')
      champ.errors.add(:value, :limit_start_date, start_date: I18n.l(start_date))
    elsif end_date.present? && date > end_date
      # i18n-tasks-use t('errors.messages.limit_end_date')
      champ.errors.add(:value, :limit_end_date, end_date: I18n.l(end_date))
    end
  end

  def safe_date(value) = value.to_date rescue nil

  def not_in_range(start_date, end_date, value)
    !(start_date..end_date).cover?(value)
  end
end
