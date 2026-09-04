# frozen_string_literal: true

# Human-readable rendering of a column value (Column#value): the dossier
# tables and cards, and any plain-text medium (PDF payloads) with html: false,
# where nothing is escaped and lists are joined as plain strings.
module ColumnValueFormatter
  module_function

  def format(column:, raw_value:, html: true)
    return if raw_value.nil?

    case column.type
    when :boolean
      if column.type_de_champ? && column.tdc_type == 'checkbox'
        raw_value ? I18n.t('activerecord.attributes.type_de_champ.type_champs.checkbox_true') : ''
      else
        raw_value ? I18n.t('utils.yes') : I18n.t('utils.no')
      end
    when :attachments
      raw_value.present? ? 'présent' : 'absent'
    when :enum
      format_enum(column:, raw_value:)
    when :enums
      format_enums(column:, raw_values: raw_value, html:)
    when :date
      raw_value = Date.parse(raw_value) if raw_value.is_a?(String)
      I18n.l(raw_value, format: :short)
    when :datetime
      raw_value = DateTime.parse(raw_value) if raw_value.is_a?(String)
      I18n.l(raw_value, format: :short_with_time)
    else
      format_text(raw_value:, html:)
    end
  end

  def format_text(raw_value:, html:)
    return raw_value.to_s if !html

    raw_value.html_safe? ? raw_value : ERB::Util.html_escape(raw_value.to_s)
  end

  def format_enums(column:, raw_values:, html: true)
    labels = raw_values.map { format_enum(column:, raw_value: it) }

    html ? ActionController::Base.helpers.safe_join(labels, ', ') : labels.join(', ')
  end

  def format_enum(column:, raw_value:)
    column.label_for_value(raw_value)
  end
end
