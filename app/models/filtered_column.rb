# frozen_string_literal: true

class FilteredColumn
  include ActiveModel::Validations

  FILTERS_VALUE_MAX_LENGTH = 4048
  # https://www.postgresql.org/docs/current/datatype-numeric.html
  PG_INTEGER_MAX_VALUE = 2147483647

  attr_reader :column, :filter

  delegate :label, to: :column

  validate :check_filter_max_length
  validate :check_filter_max_integer
  validates :filter, presence: {
    message: -> (object, _data) { "Le filtre « #{object.label} » ne peut pas être vide" },
  }

  def initialize(column:, filter: nil)
    @column = column
    @filter = filter || empty_filter
  end

  def ==(other)
    other&.column == column && other.filter_values == filter_values && other.filter_operator == filter_operator
  end

  def empty_filter
    { operator: 'match', value: [] }
  end

  def empty_filter?
    filter_operator.in?(["match", "before", "after"]) && !filter_is_active?
  end

  def id
    column.h_id.merge(filter: { operator: filter_operator, value: filter_values }).sort.to_json
  end

  def filter_operator
    filter.is_a?(Hash) ? filter&.dig(:operator) : nil
  end

  def filter_values
    Array(filter.is_a?(String) ? filter : filter&.dig(:value))
  end

  def filter_is_active?
    filter_values.any?(&:present?)
  end

  private

  def check_filter_max_length
    if filter.present? &&
      filter_values.any? { |value| value.is_a?(String) && value.length > FILTERS_VALUE_MAX_LENGTH }
      errors.add(
        :base,
        "Le filtre « #{label} » est trop long (maximum: #{FILTERS_VALUE_MAX_LENGTH} caractères)"
      )
    end
  end

  def check_filter_max_integer
    if @column.column == 'id' &&
      (filter_values.any? { |value| value.to_i > PG_INTEGER_MAX_VALUE })
      errors.add(:base, "Le filtre « #{label} » n’est pas un numéro de dossier possible")
    end
  end
end
