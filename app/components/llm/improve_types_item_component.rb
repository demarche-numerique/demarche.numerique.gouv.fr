# frozen_string_literal: true

class LLM::ImproveTypesItemComponent < LLM::SuggestionItemComponent
  def self.step_title
    t(".step_title")
  end

  def render?
    original_tdc.present?
  end

  def type_champ_label(type_champ)
    t(type_champ, scope: [:activerecord, :attributes, :type_de_champ, :type_champs])
  end

  def new_type_champ_label
    type_champ_label(payload['type_champ'])
  end

  def original_type_champ_label
    type_champ_label(original_tdc.type_champ)
  end

  def options_summary
    return nil if payload['options'].blank?

    opts = payload['options']
    type = payload['type_champ']

    case type
    when 'formatted'
      format_formatted_options(opts)
    when 'integer_number', 'decimal_number'
      format_number_options(opts)
    when 'date', 'datetime'
      format_date_options(opts)
    else
      nil
    end
  end

  def checkbox(label_class: 'fr-label')
    safe_join([
      form_builder.check_box(:verify_status, { data: { action: "click->enable-submit-if-checked#click" } }, ACCEPTED_VALUE, SKIPPED_VALUE),
      form_builder.label(:verify_status, class: label_class) do
        capture { yield if block_given? }
      end,
    ])
  end

  private

  def format_formatted_options(opts)
    parts = []
    parts << t(".letters") if opts['letters_accepted']
    parts << t(".numbers") if opts['numbers_accepted']
    parts << t(".special_characters") if opts['special_characters_accepted']
    if opts['min_character_length'] || opts['max_character_length']
      range = [opts['min_character_length'], opts['max_character_length']].compact.join('-')
      parts << t(".character_count", range:)
    end
    parts.join(', ').presence
  end

  def format_number_options(opts)
    parts = []
    parts << t(".positive") if opts['positive_number']

    min_val = opts['min_number']
    max_val = opts['max_number']
    if min_val && max_val
      parts << t(".between", min: min_val, max: max_val)
    elsif min_val
      parts << t(".min_only", min: min_val)
    elsif max_val
      parts << t(".max_only", max: max_val)
    end

    parts.join(', ').presence
  end

  def format_date_options(opts)
    parts = []
    parts << t(".past") if opts['date_in_past']

    start_date = format_date(opts['start_date'])
    end_date = format_date(opts['end_date'])
    if start_date && end_date
      parts << t(".between_dates", start_date:, end_date:)
    elsif start_date
      parts << t(".after_date", start_date:)
    elsif end_date
      parts << t(".before_date", end_date:)
    end

    parts.join(', ').presence
  end

  def format_date(date_string)
    return nil if date_string.blank?

    I18n.l(Date.parse(date_string))
  rescue ArgumentError
    date_string
  end
end
