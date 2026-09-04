# frozen_string_literal: true

class Columns::ChampColumn < Column
  attr_reader :stable_id, :tdc_type

  def initialize(procedure_id:, label:, stable_id:, tdc_type:, displayable: true, filterable: true, type: :text, options_for_select: [], mandatory:)
    @stable_id = stable_id
    @tdc_type = tdc_type
    column = tdc_type.in?(['departements', 'regions', 'pays']) ? :external_id : :value

    super(
      procedure_id:,
      table: 'type_de_champ',
      column:,
      label:,
      type:,
      displayable:,
      filterable:,
      options_for_select:,
      mandatory:
    )
  end

  def value(champ)
    if @tdc_type == 'yes_no' && (champ.nil? || champ.value.nil?)
      false
    else
      return if champ.nil? # !Champs::CheckboxChamp.nil?

      if champ.is_type?(@tdc_type)
        typed_value(champ)
      else
        cast_value(champ)
      end
    end
  end

  def filtered_ids(dossiers, filter)
    case filter
    in { operator: 'before', value: Array }
      filtered_ids_before_value(dossiers, filter[:value])
    in { operator: 'after', value: Array }
      filtered_ids_after_value(dossiers, filter[:value])
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

  def filtered_ids_before_value(dossiers, values)
    end_date = parse_datetime(values.first)

    return dossiers.ids if end_date.nil?

    filtered_ids_for_date_range(dossiers, ..end_date.beginning_of_day)
  end

  def filtered_ids_after_value(dossiers, values)
    start_date = parse_datetime(values.first)

    return dossiers.ids if start_date.nil?

    filtered_ids_for_date_range(dossiers, (start_date.end_of_day..))
  end

  def filtered_ids_for_date_range(dossiers, range)
    relation = dossiers.with_type_de_champ(stable_id)
    relation.where(champs: { column => range_for_query(range) }).ids
  end

  def filtered_ids_for_values(dossiers, search_terms)
    return dossiers.ids unless search_terms.any?(&:present?)

    return dossiers.without_type_de_champ(stable_id).ids if should_exclude_empty_values?(search_terms)

    relation = dossiers.with_type_de_champ(stable_id)

    if type == :enum
      relation.where(champs: { column => search_terms }).ids
    elsif type == :enums
      # in a multiple drop down list, the value are stored as JSON array
      quoted_search_terms = search_terms.map(&:to_json)

      relation.filter_ilike(:champs, column, quoted_search_terms).ids
    else
      relation.filter_ilike(:champs, column, search_terms).ids
    end
  end

  def should_exclude_empty_values?(search_terms)
    return true if tdc_type == "yes_no" && search_terms == [Column::NOT_FILLED_VALUE]
    return true if tdc_type == "checkbox" && search_terms == ["false"]

    false
  end

  def champ_column? = true

  def column_id = "type_de_champ/#{stable_id}"

  private

  def range_for_query(date_range)
    start_date = date_range.begin&.then { type == :date ? _1.to_date : _1 }&.iso8601
    end_date = date_range.end&.then { type == :date ? _1.to_date : _1 }&.iso8601

    start_date..end_date
  end

  def string_value(champ) = champ.public_send(column)

  def typed_value(champ)
    value = string_value(champ)

    return if value.blank?

    case type
    when :boolean
      parse_boolean(value)
    when :integer
      value.to_i
    when :decimal
      value.to_f
    when :datetime
      parse_datetime(value)
    when :date
      parse_datetime(value)&.to_date
    when :enum
      value
    when :enums
      parse_enums(value)
    else
      value
    end
  end

  def cast_value(champ)
    value = string_value(champ)

    return if value.blank?

    from_type = champ.last_write_type_champ.to_sym
    to_type = @tdc_type.to_sym

    value = case from_type
    when :date, :datetime
      parse_datetime(value)
    when :multiple_drop_down_list
      parse_enums(value)
    when :checkbox, :yes_no
      parse_boolean(value)
    else
      value
    end

    return if value.blank?

    CAST[[from_type, to_type]]&.call(value)
  end

  CAST = {
    # text
    [:text, :textarea] => -> (v) { v },
    [:text, :formatted] => -> (v) { v },
    [:text, :email] => -> (v) { v },
    [:text, :phone] => -> (v) { v },
    [:text, :decimal_number] => -> (v) { v.to_f },
    [:text, :integer_number] => -> (v) { v.to_i },
    # textarea
    [:textarea, :text] => -> (v) { v },
    [:textarea, :formatted] => -> (v) { v },
    # formatted
    [:formatted, :textarea] => -> (v) { v },
    [:formatted, :text] => -> (v) { v },
    [:formatted, :email] => -> (v) { v },
    [:formatted, :phone] => -> (v) { v },
    # civilite
    [:civilite, :text] => -> (v) { v },
    [:civilite, :textarea] => -> (v) { v },
    [:civilite, :formatted] => -> (v) { v },
    # email
    [:email, :text] => -> (v) { v },
    [:email, :textarea] => -> (v) { v },
    [:email, :formatted] => -> (v) { v },
    # phone
    [:phone, :text] => -> (v) { v },
    [:phone, :textarea] => -> (v) { v },
    [:phone, :formatted] => -> (v) { v },
    # integer_number
    [:integer_number, :decimal_number] => -> (v) { v.to_f },
    [:integer_number, :text] => -> (v) { v.to_s },
    [:integer_number, :textarea] => -> (v) { v.to_s },
    [:integer_number, :formatted] => -> (v) { v.to_s },
    # decimal_number
    [:decimal_number, :integer_number] => -> (v) { v.to_i },
    [:decimal_number, :text] => -> (v) { v.to_s },
    [:decimal_number, :textarea] => -> (v) { v.to_s },
    [:decimal_number, :formatted] => -> (v) { v.to_s },
    # date
    [:date, :datetime] => -> (v) { v.to_datetime },
    [:date, :text] => -> (v) { I18n.l(v, format: :long) },
    [:date, :textarea] => -> (v) { I18n.l(v, format: :long) },
    [:date, :formatted] => -> (v) { I18n.l(v, format: :long) },
    # datetime
    [:datetime, :date] => -> (v) { v.to_date },
    [:datetime, :text] => -> (v) { I18n.l(v) },
    [:datetime, :textarea] => -> (v) { I18n.l(v) },
    [:datetime, :formatted] => -> (v) { I18n.l(v) },
    # checkbox
    [:checkbox, :yes_no] => -> (v) { v },
    [:checkbox, :text] => -> (v) { v ? 'Oui' : 'Non' },
    [:checkbox, :textarea] => -> (v) { v ? 'Oui' : 'Non' },
    [:checkbox, :formatted] => -> (v) { v ? 'Oui' : 'Non' },
    # yes_no
    [:yes_no, :checkbox] => -> (v) { v },
    [:yes_no, :text] => -> (v) { v ? 'Oui' : 'Non' },
    [:yes_no, :textarea] => -> (v) { v ? 'Oui' : 'Non' },
    [:yes_no, :formatted] => -> (v) { v ? 'Oui' : 'Non' },
    # drop_down_list
    [:drop_down_list, :multiple_drop_down_list] => -> (v) { [v] },
    [:drop_down_list, :text] => -> (v) { v },
    [:drop_down_list, :textarea] => -> (v) { v },
    [:drop_down_list, :formatted] => -> (v) { v },
    # multiple_drop_down_list
    [:multiple_drop_down_list, :drop_down_list] => -> (v) { v.first },
    [:multiple_drop_down_list, :text] => -> (v) { v.join(', ') },
    [:multiple_drop_down_list, :textarea] => -> (v) { v.join("\n") },
    [:multiple_drop_down_list, :formatted] => -> (v) { v.join(', ') },
    # communes
    [:communes, :text] => -> (v) { v },
    [:communes, :textarea] => -> (v) { v },
    [:communes, :formatted] => -> (v) { v },
    # pre_rempli
    [:text, :pre_rempli] => -> (v) { v },
    [:textarea, :pre_rempli] => -> (v) { v },
    [:formatted, :pre_rempli] => -> (v) { v },
    [:drop_down_list, :pre_rempli] => -> (v) { v },
    [:pre_rempli, :text] => -> (v) { v },
    [:pre_rempli, :textarea] => -> (v) { v },
    [:pre_rempli, :formatted] => -> (v) { v },
    [:pre_rempli, :drop_down_list] => -> (v) { v },
  }

  def parse_boolean(value)
    case value
    when 'true', 'on', '1'
      true
    when 'false',
      false
    end
  end

  def parse_enums(value) = JSON.parse(value) rescue nil
end
