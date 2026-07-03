# frozen_string_literal: true

class Champs::COJOChamp < ChampData
  store :external_id, accessors: [:accreditation_number, :accreditation_birthdate], coder: JSON
  store_accessor :data, :accreditation_success, :accreditation_first_name, :accreditation_last_name

  def accreditation_birthdate
    Date.parse(super)
  rescue ArgumentError, TypeError
    nil
  end

  def accreditation_success?
    accreditation_success == true
  end

  def accreditation_error?
    accreditation_success == false
  end

  def has_async_external_data?
    true
  end

  def fetch_external_data
    COJOService.new.(accreditation_number:, accreditation_birthdate:)
  end

  def accreditation_number_input_id
    "#{input_id}-accreditation_number"
  end

  def accreditation_birthdate_input_id
    "#{input_id}-accreditation_birthdate"
  end

  def focusable_input_id(attribute = :value)
    accreditation_number_input_id
  end
end
