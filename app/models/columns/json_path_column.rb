# frozen_string_literal: true

class Columns::JSONPathColumn < Columns::ChampColumn
  attr_reader :jsonpath

  def initialize(procedure_id:, label:, stable_id:, tdc_type:, jsonpath:, options_for_select: [], displayable:, filterable: true, type: :text, mandatory:)
    @jsonpath = quote_string(jsonpath)

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
      filtered_ids_for_date_range(dossiers, ..parse_datetime(end_date)&.beginning_of_day)
    in { operator: 'after', value: [start_date, *_] }
      filtered_ids_for_date_range(dossiers, (parse_datetime(start_date)&.end_of_day..))
    in { operator: 'between', value: Array }
      filtered_ids_for_date_range(dossiers, date_range(filter[:value]))
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

  def column_id = "type_de_champ/#{stable_id}-#{jsonpath}"

  private

  def filtered_ids_for_date_range(dossiers, range)
    return dossiers.ids if range.begin.nil? && range.end.nil?

    start_date = range.begin&.to_date&.iso8601
    end_date = range.end&.to_date&.iso8601

    parts = []
    parts << %(@ >= "#{start_date}") if start_date
    parts << %(@ <= "#{end_date}") if end_date

    condition = %{champs.value_json @? '#{jsonpath_for_sql} ? (#{parts.join(' && ')})'}

    targeted_dossiers(dossiers, condition).ids
  end

  def filtered_ids_for_values(dossiers, search_terms)
    search_terms = Array(search_terms).compact_blank

    return dossiers.ids if search_terms.empty?

    if type == :integer
      integers = search_terms.filter_map { Integer(_1) rescue nil }

      return dossiers.ids if integers.empty?

      condition = %{champs.value_json @? '#{jsonpath_for_sql} ? (#{integers.map { |i| "@ == #{i}" }.join(" || ")})'}
    elsif type == :boolean
      # value_json holds a JSON boolean, which like_regex can never match.
      booleans = search_terms & ['true', 'false']

      return dossiers.ids if booleans.empty?

      condition = %{champs.value_json @? '#{jsonpath_for_sql} ? (#{booleans.map { "@ == #{it}" }.join(" || ")})'}
    else
      # ["normal", "nom 'quote'", "un (terme)"] compiles to:
      #
      #   @ like_regex "normal" flag "iq"
      #   || @ like_regex "nom ''quote''" flag "iq"  -- ' doubled by quote_string
      #   || @ like_regex "un (terme)" flag "iq"     -- ( ) literal, thanks to q
      #
      # i keeps the match case-insensitive; q makes the pattern a literal
      # substring, so a search term is matched rather than compiled as a regex,
      # and none can be rejected any more. `|` being literal too, terms are
      # OR-ed one at a time: a malformed one no longer takes the valid ones down.
      #
      # to_json writes the jsonpath string literal, quotes included: it escapes
      # the `"` that would close it and the `\` that would escape inside it.
      matches = search_terms.map { %{@ like_regex #{quote_string(it.to_json)} flag "iq"} }

      condition = %{champs.value_json @? '#{jsonpath_for_sql} ? (#{matches.join(' || ')})'}
    end

    targeted_dossiers(dossiers, condition).ids
  end

  # PostgreSQL's jsonpath parser rejects bare numeric member accessors (e.g. `$.row.4`),
  # typically a référentiel column whose header is a number, so those segments are
  # double-quoted (`$.row."4"`). Other segments are left as-is, keeping existing jsonpaths
  # unchanged. The Ruby JsonPath gem used in #typed_value keeps the original dot notation.
  def jsonpath_for_sql
    @jsonpath_for_sql ||= jsonpath.split('.').map { _1.match?(/\A\d/) ? "\"#{_1}\"" : _1 }.join('.')
  end

  def typed_value(champ)
    JsonPath.on(champ.value_json, jsonpath).first
  end

  def quote_string(string) = ActiveRecord::Base.connection.quote_string(string)

  def targeted_dossiers(dossiers, condition)
    dossiers.with_type_de_champ(stable_id).where(condition)
  end
end
