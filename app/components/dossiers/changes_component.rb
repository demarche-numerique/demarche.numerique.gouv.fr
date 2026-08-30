# frozen_string_literal: true

class Dossiers::ChangesComponent < ApplicationComponent
  attr_reader :changed_columns

  def initialize(changed_columns:)
    @changed_columns = changed_columns
  end

  def render? = changed_columns.present?

  private

  def change_content(changed_column)
    case changed_column.type
    when :geojson
      tag.em(t('.geojson_changed'))
    when :attachments
      attachments_change(changed_column)
    when :enums
      enums_change(changed_column)
    else
      simple_change(changed_column)
    end
  end

  def simple_change(changed_column)
    value = changed_column.value
    return tag.em(t('.removed')) if value.nil?

    tag.strong(format_value(changed_column, value))
  end

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

  def attachments_change(changed_column)
    current = attachment_filenames(changed_column.value)
    previous = attachment_filenames(changed_column.previous_value)

    diff_list(added: current - previous, removed: previous - current)
  end

  def enums_change(changed_column)
    current = Array(changed_column.value)
    previous = Array(changed_column.previous_value)

    diff_list(
      added: (current - previous).map { changed_column.label_for_value(it) },
      removed: (previous - current).map { changed_column.label_for_value(it) }
    )
  end

  def diff_list(added:, removed:)
    lines = []
    lines << diff_line(t('.added'), added) if added.present?
    lines << diff_line(t('.removed_values'), removed) if removed.present?
    return tag.em(t('.changed')) if lines.empty?

    safe_join(lines, tag.br)
  end

  def diff_line(label, values)
    safe_join([label, ' ', tag.strong(values.to_sentence)])
  end

  def attachment_filenames(value)
    Array(value).map { it.blob.filename.to_s }
  end
end
