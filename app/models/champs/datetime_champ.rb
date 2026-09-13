# frozen_string_literal: true

class Champs::DatetimeChamp < ChampData
  validates_with DateLimitValidator, if: :should_validate_in_current_context?
  normalizes :value, with: -> { DateDetectionUtils.convert_to_iso8601_datetime(it) }
  before_validation :normalize_legacy_value
  validate :iso_8601

  def search_terms
    # Text search is pretty useless for datetimes so we’re not including these champs
  end

  private

  def iso_8601
    return if DateDetectionUtils.parsable_iso8601_datetime?(value) || value.blank?

    # i18n-tasks-use t('errors.messages.not_a_datetime')
    errors.add :value, :not_a_datetime
  end

  # Normalization runs on assignment only: rows written before the current
  # parsing rules can hold values that iso_8601 rejects, which would make any
  # save fail before the caller assigns anything (RAILS-MC5).
  def normalize_legacy_value
    return if value.blank? || value_changed?
    return if DateDetectionUtils.parsable_iso8601_datetime?(value)

    Sentry.capture_message(
      "DatetimeChamp: legacy value dropped on save",
      tags: { champ: id, dossier: dossier_id }
    )
    # Reassigning routes the stored value through the normalizer.
    self.value = value
  end
end
