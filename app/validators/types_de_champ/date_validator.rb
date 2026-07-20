# frozen_string_literal: true

class TypesDeChamp::DateValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, types_de_champ)
    date_tdcs = types_de_champ
      .flat_map { it.repetition? ? it.flat_children(procedure.draft_revision) : [it] }
      .filter { |tdc| tdc.date? || tdc.datetime? }
    date_tdcs.each do |tdc|
      validate_range(procedure, attribute, tdc) if tdc.range_date?
    end
    validate_prefill_with_france_connect_information_uniqueness(procedure, attribute, date_tdcs)
  end

  private

  def validate_prefill_with_france_connect_information_uniqueness(procedure, attribute, date_tdcs)
    with_option = date_tdcs.filter(&:prefill_with_france_connect_information?)
    return if with_option.size <= 1

    with_option.each do |tdc|
      # i18n-tasks-use t('errors.messages.prefill_with_france_connect_information_taken')
      procedure.errors.add(attribute, :prefill_with_france_connect_information_taken, type_de_champ: tdc)
    end
  end

  def validate_range(procedure, attribute, tdc)
    start_str = tdc.start_date
    end_str = tdc.end_date

    if start_str.blank? && end_str.blank?
      # i18n-tasks-use t('errors.messages.missing_range_date_rules')
      procedure.errors.add(attribute, :missing_range_date_rules, type_de_champ: tdc)
      return
    end

    start_date = safe_datetime(start_str, tdc)
    end_date = safe_datetime(end_str, tdc)

    if start_date && end_date && start_date > end_date
      # i18n-tasks-use t('errors.messages.invalid_range_date_rules')
      procedure.errors.add(attribute, :invalid_range_date_rules, type_de_champ: tdc)
    end
  end

  def safe_datetime(value, tdc)
    return nil if value.blank?

    if tdc.datetime?
      DateTime.parse(value) rescue nil
    else
      Date.parse(value) rescue nil
    end
  end
end
