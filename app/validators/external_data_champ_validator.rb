# frozen_string_literal: true

class ExternalDataChampValidator < ActiveModel::Validator
  # Required checks are delegated to check_mandatory_and_visible_champs_public.
  def validate(record)
    if record.external_data_required_for_conditions?
      legacy_validate(record)
    else
      lenient_validate(record)
    end
  end

  private

  # Historical behavior: any pending or external_error blocks submission.
  # Used when another field's logic condition depends on this champ's value_json.
  def legacy_validate(record)
    if record.pending?
      # User filled the field, but background job is still running.
      record.errors.add(:value, :api_response_pending)
    elsif record.external_error?
      # User filled the field, but background job failed.
      record.errors.add(:value, error_key_for_api_response_code(record))
    end
  end

  # Lenient behavior (#12997): only an explicit :not_found blocks submission.
  # Pending and :technical_error (including legacy nil kind) let the user submit.
  def lenient_validate(record)
    return unless record.external_error?
    return unless first_exception_kind(record) == :not_found

    record.errors.add(:value, error_key_for_api_response_code(record))
  end

  def first_exception_kind(record)
    record.fetch_external_data_exceptions&.first&.kind
  end

  def error_key_for_api_response_code(record)
    first_exception = record.fetch_external_data_exceptions&.first
    return :code_unknown if first_exception.nil?

    http_status = first_exception.code
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
