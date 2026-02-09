# frozen_string_literal: true

class Instructeurs::CellComponent < ApplicationComponent
  include DossierHelper

  def initialize(dossier:, column:)
    @dossier = dossier
    @column = column
  end

  def call
    advanced_layout || simple_layout
  end

  private

  def advanced_layout
    if @column.email?
      email_and_tiers(@dossier)
    elsif @column.dossier_labels?
      tags_label(@dossier.labels)
    elsif @column.avis?
      sum_up_avis(@dossier.avis)
    end
  end

  def simple_layout
    raw_value = raw_value_for_column(@dossier, @column)
    return '' if raw_value.nil?

    format(raw_value, @column.type)
  end

  def raw_value_for_column(dossier, column)
    data = if @column.champ_column?
      @dossier.champs.find { _1.stable_id == column.stable_id }
    else
      @dossier
    end

    @column.value(data)
  end

  def format(raw_value, type)
    case @column.type
    when :boolean
      if @column.type_de_champ? && @column.tdc_type == 'checkbox'
        raw_value ? I18n.t('activerecord.attributes.type_de_champ.type_champs.checkbox_true') : ''
      else
        raw_value ? I18n.t('utils.yes') : I18n.t('utils.no')
      end
    when :attachments
      raw_value.present? ? 'présent' : 'absent'
    when :enum
      format_enum(column: @column, raw_value:)
    when :enums
      format_enums(column: @column, raw_values: raw_value)
    when :date
      raw_value = Date.parse(raw_value) if raw_value.is_a?(String)
      DateFormatHelper.short(raw_value)
    when :datetime
      raw_value = DateTime.parse(raw_value) if raw_value.is_a?(String)
      DateFormatHelper.short_with_time(raw_value)
    else
      # Escape if it's a string and not already safe
      raw_value.html_safe? ? raw_value : html_escape(raw_value.to_s)
    end
  end

  def format_enums(column:, raw_values:)
    safe_join(raw_values.map { format_enum(column:, raw_value: _1) }, ', ')
  end

  def format_enum(column:, raw_value:)
    column.label_for_value(raw_value)
  end

  def email_and_tiers(dossier)
    email = dossier&.user&.email || dossier.user_email_for(:display)

    if dossier.for_tiers
      prenom, nom = dossier&.individual&.prenom, dossier&.individual&.nom
      safe_join([email, I18n.t('views.instructeurs.dossiers.acts_on_behalf'), prenom, nom], ' ')
    else
      html_escape(email)
    end
  end

  def sum_up_avis(avis)
    result = avis.map(&:question_answer)&.compact&.tally
      &.map { |k, v| I18n.t("helpers.label.question_answer_with_count.#{k}", count: v) }

    result ? safe_join(result, ' / ') : nil
  end
end
