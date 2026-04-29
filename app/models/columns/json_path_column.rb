# frozen_string_literal: true

class Columns::JSONPathColumn < Columns::ChampColumn
  attr_reader :jsonpath, :filter_jsonpath

  def initialize(procedure_id:, label:, stable_id:, tdc_type:, jsonpath:, filter_jsonpath: nil, options_for_select: [], displayable:, filterable: true, type: :text, mandatory:)
    @jsonpath = quote_string(jsonpath)
    @filter_jsonpath = quote_string(filter_jsonpath || jsonpath)

    super(
      procedure_id:,
      label:,
      stable_id:,
      tdc_type:,
      displayable:,
      filterable:,
      type:,
      options_for_select:,
      mandatory:
    )
  end

  def filtered_ids(dossiers, filter)
    case filter
    in { operator: 'before', value: [end_date, *_] }
      filtered_ids_for_date_range(dossiers, ..end_date&.then { Time.zone.parse(_1) }&.beginning_of_day)
    in { operator: 'after', value: [start_date, *_] }
      filtered_ids_for_date_range(dossiers, (start_date&.then { Time.zone.parse(_1) }&.end_of_day..))
    in { operator: 'this_week' }
      filtered_ids_for_date_range(dossiers, Time.current.all_week)
    in { operator: 'this_month' }
      filtered_ids_for_date_range(dossiers, Time.current.all_month)
    in { operator: 'this_year' }
      filtered_ids_for_date_range(dossiers, Time.current.all_year)
    else
      filtered_ids_for_values(dossiers, filter[:value])
    end
  end

  private

  def filtered_ids_for_date_range(dossiers, range)
    return dossiers.ids if range.begin.nil? && range.end.nil?

    start_date = range.begin&.to_date&.iso8601
    end_date = range.end&.to_date&.iso8601

    parts = []
    parts << %(@ >= "#{start_date}") if start_date
    parts << %(@ <= "#{end_date}") if end_date

    condition = sanitize_sql(%{champs.value_json @? '#{filter_jsonpath} ? (#{parts.join(' && ')})'})

    targeted_dossiers(dossiers, condition).ids
  end

  def filtered_ids_for_values(dossiers, search_terms)
    search_terms = Array(search_terms).compact_blank

    return dossiers.ids if search_terms.empty?

    if type == :integer
      integers = search_terms.filter_map { Integer(_1) rescue nil }

      return dossiers.ids if integers.empty?

      condition = sanitize_sql(%{champs.value_json @? '#{filter_jsonpath} ? (#{integers.map { |i| "@ == #{i}" }.join(" || ")})'})
    else
      value = quote_string(search_terms.join('|'))
      condition = sanitize_sql(%{champs.value_json @? '#{filter_jsonpath} ? (@ like_regex "#{value}" flag "i")'})
    end

    targeted_dossiers(dossiers, condition).ids

  rescue ActiveRecord::StatementInvalid => e
    if e.cause.is_a?(PG::InvalidRegularExpression)
      Rails.logger.warn("filtered_ids fallback: Invalid regex — #{e.message}")
      []
    else
      raise
    end
  end

  def column_id = "type_de_champ/#{stable_id}-#{jsonpath}"

  def typed_value(champ)
    JsonPath.on(champ.value_json, jsonpath).first
  end

  def quote_string(string) = ActiveRecord::Base.connection.quote_string(string)

  def sanitize_sql(sql) = ActiveRecord::Base.sanitize_sql(sql)

  private

  def targeted_dossiers(dossiers, condition)
    dossiers.with_type_de_champ(stable_id).where(condition)
  end
end
