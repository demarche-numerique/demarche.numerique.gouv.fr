# frozen_string_literal: true

class TypesDeChamp::NumberValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, types_de_champ)
    types_de_champ
      .flat_map { it.repetition? ? it.flat_children(procedure.draft_revision) : [it] }
      .filter { |tdc| tdc.decimal_number? || tdc.integer_number? }.each do |tdc|
      validate_range(procedure, attribute, tdc) if tdc.range_number?
    end
  end

  private

  def validate_range(procedure, attribute, tdc)
    min_str = tdc.min_number
    max_str = tdc.max_number

    if min_str.blank? && max_str.blank?
      # i18n-tasks-use t('errors.messages.missing_range_rules')
      procedure.errors.add(attribute, :missing_range_rules, type_de_champ: tdc)
      return
    end

    min = tdc.decimal_number? ? min_str.to_f : min_str.to_i
    max = tdc.decimal_number? ? max_str.to_f : max_str.to_i

    if min > max
      # i18n-tasks-use t('errors.messages.invalid_range_rules')
      procedure.errors.add(attribute, :invalid_range_rules, type_de_champ: tdc)
    end

    if tdc.positive_number? && max < 0
      # i18n-tasks-use t('errors.messages.invalid_positive_range_rules')
      procedure.errors.add(attribute, :invalid_positive_range_rules, type_de_champ: tdc)
    end
  end
end
