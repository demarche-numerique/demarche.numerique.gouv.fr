# frozen_string_literal: true

class Champs::AddressChamp < Champs::TextChamp
  store_accessor :value_json,
    :not_in_ban,
    :postal_code,
    :country_code,
    :country_name,
    :department_code,
    :department_name,
    :region_code,
    :region_name,
    :city_code,
    :city_name,
    :street_address

  before_validation :set_full_address, if: :should_set_full_address?, on: :update

  # Legacy attributes
  def code_departement
    department_code
  end

  def code_region
    region_code
  end

  def full_address?
    if france?
      city_code.present? && street_address.present?
    else
      postal_code.present? && city_name.present? && street_address.present?
    end
  end

  def migrated_legacy_address?
    not_ban? && value_json.keys.sort == %w[not_in_ban street_address label].sort
  end

  def ban?
    france? && !(not_ban? || legacy_not_ban?)
  end

  def france?
    country_code == 'FR'
  end

  def international?
    !france?
  end

  def country_code
    super.presence || 'FR'
  end

  def country_name
    if country_code.present?
      APIGeoService.country_name(country_code)
    else
      super
    end
  end

  def street_address
    if legacy_not_ban?
      value
    else
      super
    end
  end

  # We pass thru this setter when the user choose to fill his address with the address component form, meaning he will have to choose a commune code by himself
  def commune_code=(code)
    if code.blank?
      self.city_code = nil
      self.city_name = nil
      self.postal_code = nil
    else
      @commune_code = code
    end
  end

  def address=(value)
    return if not_ban?
    if value.blank?
      self.value_json = { country_code: 'FR' }
    else
      self.value_json = JSON.parse(value)
    end
  rescue JSON::ParserError
    self.value_json = { country_code: 'FR' }
  end

  def address
    self.value_json if full_address?
  end

  def selected_key
    address_label if ban? && full_address?
  end

  def selected_items
    if selected_key.present?
      [{ label: address_label, value: selected_key, data: value_json }]
    else
      []
    end
  end

  def commune_selected_key
    "#{city_code}-#{postal_code}" if city_code.present?
  end

  def commune_selected_items
    if city_code.present?
      [{ label: commune_name, value: commune_selected_key }]
    else
      []
    end
  end

  def address_label
    value_json&.dig('label') || value
  end

  def search_terms
    [address_label, department_name, region_name, city_name].compact if full_address?
  end

  def departement_code_and_name
    if department_code.present?
      "#{department_code} – #{department_name}"
    end
  end

  def commune_name
    if international?
      city_name
    elsif department_code.present?
      commune_name = APIGeoService.commune_name(department_code, city_code)
      return commune_name if postal_code.blank?
      "#{commune_name} (#{postal_code})"
    end
  end

  def departement
    if department_code.present?
      { code: department_code, name: department_name }
    end
  end

  def commune
    return unless full_address?
    return if department_code == '99'

    commune_name = APIGeoService.commune_name(department_code, city_code)
    commune_code = APIGeoService.commune_code(department_code, city_name)

    if commune_name.present?
      {
        code: city_code,
        name: commune_name,
      }
    elsif commune_code.present?
      {
        code: commune_code,
        name: city_name,
      }
    else
      {
        code: city_code,
        name: city_name,
      }
    end.merge(postal_code:)
  end

  # We know that not ban address where just fulled input without choosing an element from the autocomplete
  def legacy_not_ban?
    value.present? && value_json.blank?
  end

  def not_ban?
    not_in_ban == 'true'
  end

  def legend_label?
    true
  end

  def html_label?
    false
  end

  def validate_completed
    if ban? && mandatory? && !full_address?
      errors.add(:value, :missing)
    elsif not_ban? && france?
      validate_not_in_ban_completed
    elsif international?
      validate_international_completed
    end
  end

  private

  def format_label
    if international?
      "#{street_address}, #{city_name} #{postal_code} #{country_name}"
    else
      "#{street_address}, #{city_name} #{postal_code}"
    end
  end

  def should_set_full_address?
    value_json_changed? || @commune_code.present?
  end

  def become_france?
    country_code_changed? && france? && country_code_was.present?
  end

  def become_international?
    country_code_changed? && international? && country_code_was.in?(['FR', nil])
  end

  def become_ban?
    not_in_ban_changed? && not_in_ban_was == 'true' && not_in_ban == ''
  end

  def become_not_ban?
    not_in_ban_changed? && not_in_ban_was == '' && not_in_ban == 'true'
  end

  def set_full_address
    address_data = self.value_json
    if become_france? || become_international?
      address_data.merge!(
        'department_code' => nil,
        'department_name' => nil,
        'region_code' => nil,
        'region_name' => nil,
        'city_code' => nil,
        'city_name' => nil,
        'street_address' => nil,
        'postal_code' => nil
      )
      if become_international?
        address_data['department_code'] = '99'
        address_data['department_name'] = APIGeoService.departement_name('99')
      end
    elsif become_ban?
      address_data = { 'not_in_ban': '', 'country_code': 'FR' }
    elsif become_not_ban?
      address_data = { 'not_in_ban': 'true' }
    end

    if france?
      if @commune_code.present?
        city_data = APIGeoService.parse_city_code_and_postal_code(@commune_code)
        address_data.merge!(city_data) if city_data.present?
      end

      address_data['country_code'] ||= 'FR'
    end

    self.value_json = address_data.compact
    self.value = address_label

    if full_address? && !ban?
      self.value_json['label'] = format_label
    end
  end

  private

  def validate_not_in_ban_completed
    if street_address.blank? && (mandatory? || commune_name.present?)
      errors.add(:street_address, :required)
    end

    if commune_name.blank? && (mandatory? || street_address.present?)
      errors.add(:commune_name, :required)
    end
  end

  def validate_international_completed
    if street_address.blank? && (mandatory? || city_name.present? || postal_code.present?)
      errors.add(:street_address, :required)
    end

    if city_name.blank? && (mandatory? || street_address.present? || postal_code.present?)
      errors.add(:city_name, :required)
    end

    if postal_code.blank? && (mandatory? || street_address.present? || city_name.present?)
      errors.add(:postal_code, :required)
    end
  end
end
