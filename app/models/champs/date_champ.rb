# frozen_string_literal: true

class Champs::DateChamp < ChampData
  attr_accessor :prefilling_from_france_connect_information

  validates_with DateLimitValidator, if: :should_validate_in_current_context?
  normalizes :value, with: -> { DateDetectionUtils.convert_to_iso8601_date(it) }
  before_validation :normalize_legacy_value
  before_save :clear_prefilled_from_france_connect_information_flag_if_modified
  validate :iso_8601

  def search_terms
    # Text search is pretty useless for dates so we’re not including these champs
  end

  private

  def clear_prefilled_from_france_connect_information_flag_if_modified
    return if prefilling_from_france_connect_information
    return if !value_changed?
    return if data.blank?

    data.delete("prefilled_from_france_connect_information")
  end

  def iso_8601
    return if DateDetectionUtils.parsable_iso8601_date?(value) || value.blank?

    # i18n-tasks-use t('errors.messages.not_a_date')
    errors.add :value, :not_a_date
  end

  # Normalization runs on assignment only: rows written before the current
  # parsing rules can hold values that iso_8601 rejects, which would make any
  # save fail before the caller assigns anything (RAILS-MC5).
  def normalize_legacy_value
    return if value.blank? || value_changed?
    return if DateDetectionUtils.parsable_iso8601_date?(value)

    Sentry.capture_message(
      "DateChamp: legacy value dropped on save",
      tags: { champ: id, dossier: dossier_id }
    )
    # Reassigning routes the stored value through the normalizer.
    self.value = value
  end
end
