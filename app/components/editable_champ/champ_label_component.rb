# frozen_string_literal: true

class EditableChamp::ChampLabelComponent < ApplicationComponent
  include Dsfr::InputErrorable
  include ChampAriaLabelledbyHelper

  attr_reader :attribute

  def initialize(form:, champ:, seen_at: nil, row_number: nil)
    @form, @champ, @seen_at, @row_number = form, champ, seen_at, row_number
    @attribute = :value
  end

  def describedby_present?
    @champ.description.present? || expression_reguliere_indications.present? || referentiel_hint.present? || hints_for_champ.any?
  end

  def expression_reguliere_indications
    @champ.type_de_champ.expression_reguliere_indications if @champ.formatted? && @champ.type_de_champ.formatted_advanced?
  end

  def referentiel_hint
    @champ.type_de_champ.referentiel&.hint if @champ.type_de_champ.referentiel?
  end

  def hints_for_champ
    @hints_for_champ ||= begin
      hints = []

      if hint_renderable?
        hints << if @champ.date? || @champ.datetime?
          { text: hint, controller: 'date-input-hint', id: "#{@champ.html_id}-format-hint" }
        else
          { text: hint, controller: nil }
        end
      end

      extra_hints =
        if @champ.formatted?
          formatted_champ_hints
        elsif @champ.date? || @champ.datetime?
          date_hints
        elsif @champ.integer_number? || @champ.decimal_number?
          number_hints
        elsif @champ.textarea?
          text_hints
        elsif @champ.dossier_link?
          dossier_link_hints
        else
          []
        end

      extra_hints.each do |text|
        hints << { text:, controller: nil }
      end

      hints
    end
  end

  private

  # The dossier_link hint depends on its actual input mode: a select prompt when the
  # user picks among their dossiers, the free-text format otherwise.
  def dossier_link_hints
    key = @champ.selectable? ? :select : :free
    [I18n.t("activerecord.attributes.champs/dossier_link_champ.hints.#{key}", application_name: APPLICATION_NAME)]
  end

  def formatted_champ_hints
    if @champ.formatted_simple?
      hints = []

      letters_accepted = @champ.letters_accepted?
      numbers_accepted = @champ.numbers_accepted?
      special_characters_accepted = @champ.special_characters_accepted?

      allowed_parts = []
      allowed_parts << :letters if letters_accepted
      allowed_parts << :numbers if numbers_accepted
      allowed_parts << :special_characters if special_characters_accepted

      if allowed_parts.any?
        allowed_key = allowed_parts.join('_and_')
        hints << I18n.t("activerecord.attributes.champs/formatted_champ.hints.allowed.#{allowed_key}")
      end

      min = @champ.min_character_length
      max = @champ.max_character_length

      if min.present? && max.present?
        if min == max
          hints << I18n.t('activerecord.attributes.champs/formatted_champ.hints.range.exactly', count: min)
        else
          hints << I18n.t('activerecord.attributes.champs/formatted_champ.hints.range.both', min:, max:)
        end
      elsif min.present?
        hints << I18n.t('activerecord.attributes.champs/formatted_champ.hints.range.min_only', min:)
      elsif max.present?
        hints << I18n.t('activerecord.attributes.champs/formatted_champ.hints.range.max_only', max:)
      end

      hints
    elsif @champ.formatted_advanced?
      []
    else
      []
    end
  end

  def date_hints
    hints = []

    if @champ.date_in_past?
      hints << I18n.t('activerecord.attributes.champs/date_champ.hints.date_in_past')
    end

    if @champ.range_date?
      start_date = @champ.start_date.presence
      end_date   = @champ.end_date.presence

      if start_date && end_date
        hints << I18n.t('activerecord.attributes.champs/date_champ.hints.range.both',
                        start_date: I18n.l(Time.zone.parse(start_date).to_date, format: :short),
                        end_date: I18n.l(Time.zone.parse(end_date).to_date, format: :short))
      elsif start_date
        hints << I18n.t('activerecord.attributes.champs/date_champ.hints.range.start_date_only',
                        start_date: I18n.l(Time.zone.parse(start_date).to_date, format: :short))
      elsif end_date
        hints << I18n.t('activerecord.attributes.champs/date_champ.hints.range.end_date_only',
                        end_date: I18n.l(Time.zone.parse(end_date).to_date, format: :short))
      end
    end

    hints
  end

  def number_hints
    hints = []

    if @champ.positive_number?
      hints << I18n.t('activerecord.attributes.champs/decimal_number_champ.hints.positive_number')
    end

    if @champ.range_number?
      min = @champ.min_number.presence
      max = @champ.max_number.presence

      if min && max
        hints << I18n.t('activerecord.attributes.champs/decimal_number_champ.hints.range.both', min: min, max: max)
      elsif min
        hints << I18n.t('activerecord.attributes.champs/decimal_number_champ.hints.range.min_only', min: min)
      elsif max
        hints << I18n.t('activerecord.attributes.champs/decimal_number_champ.hints.range.max_only', max: max)
      end
    end

    hints
  end

  def text_hints
    hints = []

    if @champ.character_limit_base&.positive?
      hints << I18n.t('activerecord.attributes.champs/textarea_champ.hints.recommended_size', size: @champ.character_limit_base)
    end

    hints
  end
end
