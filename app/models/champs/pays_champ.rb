# frozen_string_literal: true

class Champs::PaysChamp < Champs::TextChamp
  with_options if: :validate_champ_value? do
    validates :external_id, inclusion: APIGeoService.countries.pluck(:code), allow_nil: true, allow_blank: false
    validates :value, inclusion: APIGeoService.countries.pluck(:name), allow_nil: true, allow_blank: false
  end

  # def value=(code) can reset champs to nil if value is empty, in case of prefill
  #   we do not want to try to save the champ with an nil value
  with_options if: -> { validation_context == :prefill } do
    validates :external_id, inclusion: APIGeoService.countries.pluck(:code), allow_nil: false, allow_blank: false
    validates :value, inclusion: APIGeoService.countries.pluck(:name), allow_nil: false, allow_blank: false
  end

  def selected
    code || value
  end

  def value=(code)
    if code&.size == 2
      self.external_id = code
      super(APIGeoService.country_name(code, locale: 'FR'))
    elsif code.blank?
      self.external_id = nil
      super(nil)
    elsif code != value
      self.external_id = APIGeoService.country_code(code) # lookup by code which is a country name

      if self.external_id # if we match a country code, lookup for country name with code
        super(APIGeoService.country_name(self.external_id, locale: 'FR'))
      else # if we did not match any country code, external_id is nil as well as value
        super(nil)
      end
    end
  end

  def code
    external_id || APIGeoService.country_code(value)
  end

  def name
    if external_id.present?
      APIGeoService.country_name(external_id)
    else
      value.present? ? value.to_s : ''
    end
  end
end
