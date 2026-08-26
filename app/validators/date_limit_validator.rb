# frozen_string_literal: true

class DateLimitValidator < ActiveModel::Validator
  BIRTHDATE_MIN = Date.new(1900, 1, 1)

  # Pure function of (value, type_de_champ) so prefill screening can share the
  # range logic. type_de_champ is anything responding to the date option
  # readers (a Champ delegates them, and so does a Prefill).
  # Returns an array of [error_key, details] pairs.
  def self.violations(value, type_de_champ)
    date = safe_date(value)
    return [] if date.nil?

    if type_de_champ.birthdate?
      birthdate_violations(date)
    else
      violations = []
      violations.concat(in_past_violations(date)) if type_de_champ.date_in_past?
      violations.concat(in_range_violations(date, type_de_champ)) if type_de_champ.range_date?
      violations
    end
  end

  def validate(champ)
    self.class.violations(champ.value, champ).each do |error, details|
      champ.errors.add(:value, error, **details)
    end
  end

  class << self
    def safe_date(value) = value.to_date rescue nil

    private

    def birthdate_violations(date)
      if !(BIRTHDATE_MIN..Date.today).cover?(date)
        # i18n-tasks-use t('errors.messages.invalid_birthdate')
        [[:invalid_birthdate, {}]]
      else
        []
      end
    end

    def in_past_violations(date)
      if date >= Date.today
        # i18n-tasks-use t('errors.messages.date_in_past')
        [[:date_in_past, {}]]
      else
        []
      end
    end

    def in_range_violations(date, type_de_champ)
      start_date, end_date = [type_de_champ.start_date, type_de_champ.end_date].map { safe_date(it) }

      if start_date.present? && end_date.present? && !(start_date..end_date).cover?(date)
        # i18n-tasks-use t('errors.messages.not_in_range_date')
        [[:not_in_range_date, { start_date: I18n.l(start_date), end_date: I18n.l(end_date) }]]
      elsif start_date.present? && date < start_date
        # i18n-tasks-use t('errors.messages.limit_start_date')
        [[:limit_start_date, { start_date: I18n.l(start_date) }]]
      elsif end_date.present? && date > end_date
        # i18n-tasks-use t('errors.messages.limit_end_date')
        [[:limit_end_date, { end_date: I18n.l(end_date) }]]
      else
        []
      end
    end
  end
end
