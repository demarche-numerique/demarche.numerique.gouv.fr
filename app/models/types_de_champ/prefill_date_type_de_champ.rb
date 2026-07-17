# frozen_string_literal: true

class TypesDeChamp::PrefillDateTypeDeChamp < TypesDeChamp::PrefillTypeDeChamp
  private

  def screened_value(champ, value)
    iso_value = convert_value(value)
    return nil if iso_value.nil?
    return nil if DateLimitValidator.violations(iso_value, self).any?

    iso_value
  end

  def convert_value(value)
    case value
    when Numeric
      timestamp_to_iso(value)
    when String
      if DateDetectionUtils.likely_string_timestamp?(value)
        timestamp = DateDetectionUtils.convert_unix_timestamp(value)
        timestamp_to_iso(timestamp)
      elsif datetime?
        DateDetectionUtils.convert_to_iso8601_datetime(value)
      else
        DateDetectionUtils.convert_to_iso8601_date(value)
      end
    end
  end

  def timestamp_to_iso(timestamp)
    return nil if timestamp.nil?

    if datetime?
      Time.zone.at(timestamp).iso8601
    else
      Time.zone.at(timestamp).to_date.iso8601
    end
  end
end
