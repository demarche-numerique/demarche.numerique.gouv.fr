# frozen_string_literal: true

class JustificatifDomicile
  include ActiveModel::Model
  include ActiveModel::Attributes

  # 2ddoc-specific
  attribute :beneficiary, :string
  attribute :issue_date, :date
  attribute :two_ddoc, :boolean

  # APIGeoService.parse_ban_address output
  attribute :label, :string
  attribute :type, :string
  attribute :street_address, :string
  attribute :street_number, :string
  attribute :street_name, :string
  attribute :postal_code, :string
  attribute :city_code, :string
  attribute :city_name, :string
  attribute :department_code, :string
  attribute :department_name, :string
  attribute :region_code, :string
  attribute :region_name, :string
  attribute :country_code, :string
  attribute :country_name, :string
end
