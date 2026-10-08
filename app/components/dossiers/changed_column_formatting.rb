# frozen_string_literal: true

# Formats a value the way the usager sees it in a change message.
module Dossiers::ChangedColumnFormatting
  private

  def format_value(column, value)
    case column.type
    when :boolean
      value ? t('utils.yes') : t('utils.no')
    when :enum
      column.label_for_value(value)
    when :date
      I18n.l(value, format: :short)
    when :datetime
      I18n.l(value, format: :short_with_time)
    else
      value.to_s
    end
  end
end
