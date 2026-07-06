# frozen_string_literal: true

class ExternalDataChampValidator < ActiveModel::Validator
  # Required checks are delegated to Champ#validate_completed (:champ_completeness context).
  def validate(record)
    if record.permissive_external_data_validation?
      permissive_validate(record)
    else
      strict_validate(record)
    end
  end

  private

  def strict_validate(record)
    if record.pending?
      # User filled the field, but background job is still running.
      record.errors.add(:external_id, :api_response_pending)
    elsif record.external_error?
      # User filled the field, but background job failed.
      record.errors.add(:external_id, error_key_for(record, record.fetch_external_data_exceptions&.last))
    end
  end

  def permissive_validate(record)
    return unless record.external_data_not_found?

    record.errors.add(:value, error_key_for(record, record.fetch_external_data_exceptions.last))
  end

  def error_key_for(record, exception)
    return :code_unknown if exception.nil?

    http_status = exception.code
    error_key = :"code_#{http_status}"

    if http_status && translation_exists_for?(error_key, record)
      error_key
    else
      :api_response_error
    end
  end

  def translation_exists_for?(error_key, record)
    model_key = record.class.model_name.i18n_key

    I18n.exists?("activerecord.errors.models.#{model_key}.attributes.value.#{error_key}") ||
      I18n.exists?("activerecord.errors.messages.#{error_key}")
  end
end
