# frozen_string_literal: true

module ChampValidateConcern
  extend ActiveSupport::Concern

  included do
    validates_with ExternalDataChampValidator, if: :validate_external_data_response?
    validate :validate_completed, on: :champ_completeness, if: :visible?
  end

  # Overridden by champs with multi-input completeness rules (address, linked drop down)
  def validate_completed
    errors.add(:value, :missing) if mandatory_blank?
  end

  # Validation can add the errors to another instance of the champ, nested on the dossier.
  def dossier_nested_errors
    dossier.errors.filter { it.is_a?(ActiveModel::NestedError) && it.inner_error.base.try(:public_id) == public_id }
  end

  private

  def should_validate_in_current_context?
    # validation_context is an array when champs are validated for completeness
    # ([:champ_value, :champ_completeness])
    Array(validation_context).include?(:champ_value) && visible?
  end

  def validate_external_data_response?
    should_validate_in_current_context? && has_async_external_data? && external_data_needed_for_validation?
  end
end
