# frozen_string_literal: true

class Champs::DateChamp < Champ
  validates_with DateLimitValidator, if: :validate_champ_value?
  before_validation :convert_to_iso8601_date, unless: -> { validation_context == :prefill }
  validate :iso_8601

  def search_terms
    # Text search is pretty useless for dates so we’re not including these champs
  end

  private

  def convert_to_iso8601_date
    self.value = DateDetectionUtils.convert_to_iso8601_date(value)
  end

  def iso_8601
    return if DateDetectionUtils.parsable_iso8601_date?(value) || value.blank?

    # i18n-tasks-use t('errors.messages.not_a_date')
    errors.add :date, :not_a_date
  end
end
