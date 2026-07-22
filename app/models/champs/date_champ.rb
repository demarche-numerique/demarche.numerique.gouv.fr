# frozen_string_literal: true

class Champs::DateChamp < ChampData
  attr_accessor :prefilling_from_france_connect_information

  validates_with DateLimitValidator, if: :should_validate_in_current_context?
  normalizes :value, with: -> { DateDetectionUtils.convert_to_iso8601_date(it) }
  before_save :clear_prefilled_from_france_connect_information_flag_if_modified
  validate :iso_8601

  def search_terms
    # Text search is pretty useless for dates so we’re not including these champs
  end

  private

  def clear_prefilled_from_france_connect_information_flag_if_modified
    return if prefilling_from_france_connect_information
    # a just-created record (e.g. a buffer champ cloned from the main stream)
    # is a replication, not a user modification of the prefilled value
    return if previously_new_record?
    return if !value_changed?
    return if data.blank?

    data.delete("prefilled_from_france_connect_information")
  end

  def iso_8601
    return if DateDetectionUtils.parsable_iso8601_date?(value) || value.blank?

    # i18n-tasks-use t('errors.messages.not_a_date')
    errors.add :date, :not_a_date
  end
end
