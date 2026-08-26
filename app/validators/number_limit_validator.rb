# frozen_string_literal: true

class NumberLimitValidator < ActiveModel::Validator
  # Pure function of (value, type_de_champ) so prefill screening can share the
  # range logic. type_de_champ is anything responding to the number option
  # readers (a Champ delegates them, and so does a Prefill).
  # Returns an array of [error_key, details] pairs.
  def self.violations(value, type_de_champ)
    return [] if value.blank?

    positive_violations(value, type_de_champ) + range_violations(value, type_de_champ)
  end

  def validate(record)
    self.class.violations(record.value, record).each do |error, details|
      record.errors.add(:value, error, **details)
    end
  end

  class << self
    private

    def positive_violations(value, type_de_champ)
      if type_de_champ.positive_number? && convert_to_number(value, type_de_champ).negative?
        # i18n-tasks-use t('errors.messages.not_positive')
        [[:not_positive, {}]]
      else
        []
      end
    end

    def range_violations(value, type_de_champ)
      return [] if !type_de_champ.range_number?

      number = convert_to_number(value, type_de_champ)
      min = convert_to_number(type_de_champ.min_number, type_de_champ)
      max = convert_to_number(type_de_champ.max_number, type_de_champ)

      if min.present? && max.present? && !(min..max).cover?(number)
        # i18n-tasks-use t('errors.messages.not_in_range')
        [[:not_in_range, { min:, max: }]]
      elsif min.present? && number < min
        # i18n-tasks-use t('errors.messages.limit_min')
        [[:limit_min, { min: }]]
      elsif max.present? && number > max
        # i18n-tasks-use t('errors.messages.limit_max')
        [[:limit_max, { max: }]]
      else
        []
      end
    end

    def convert_to_number(raw_value, type_de_champ)
      return '' if raw_value.blank?
      type_de_champ.integer_number? ? raw_value.to_i : raw_value.to_f
    end
  end
end
