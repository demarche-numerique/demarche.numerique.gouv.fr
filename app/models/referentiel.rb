# frozen_string_literal: true

class Referentiel < ApplicationRecord
  self.ignored_columns += [:use_tiptap, :url, :test_data]

  has_many :items, -> { order(:id) }, class_name: 'ReferentielItem', dependent: :destroy, inverse_of: :referentiel
  has_many :types_de_champ, inverse_of: :referentiel, dependent: :nullify

  def headers_with_path
    headers.map { [_1, self.class.header_to_path(_1)] }
  end

  def drop_down_options
    path = self.class.header_to_path(headers.first)
    items.filter_map { _1.value(path) }
  end

  def options_for_select
    path = self.class.header_to_path(headers.first)
    items.filter_map do |item|
      value = item.value(path)
      [value, item.id.to_s] if value.present?
    end
  end

  def options_for_path(path)
    value_path = self.class.header_to_path(headers.first)
    items.to_set { _1.value(path) if _1.value(value_path).present? }.compact.sort.map { [_1, _1] }
  end

  def self.header_to_path(header)
    header.to_s.parameterize.underscore
  end
end
