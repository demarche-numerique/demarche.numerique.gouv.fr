# frozen_string_literal: true

class TypesDeChamp::Formatted < TypeDeChamp
  def self.option_keys
    [
      :formatted_mode, :numbers_accepted, :letters_accepted, :special_characters_accepted,
      :min_character_length, :max_character_length,
      :expression_reguliere, :expression_reguliere_indications, :expression_reguliere_exemple_text, :expression_reguliere_error_message,
    ]
  end

  store_accessor :options,
                 :formatted_mode,
                 :numbers_accepted,
                 :letters_accepted,
                 :special_characters_accepted,
                 :min_character_length,
                 :max_character_length,
                 :expression_reguliere,
                 :expression_reguliere_indications,
                 :expression_reguliere_exemple_text,
                 :expression_reguliere_error_message

  def prefillable? = true
  def customizable? = true
  def formatted_simple? = formatted_mode != 'advanced'
  def formatted_advanced? = formatted_mode == 'advanced'
  boolean_options :letters_accepted, :numbers_accepted, :special_characters_accepted

  after_initialize :set_default_options

  def invalid_regexp?
    self.errors.delete(:expression_reguliere)
    self.errors.delete(:expression_reguliere_exemple_text)

    return false if expression_reguliere.blank?
    return false if expression_reguliere_exemple_text.blank?
    return false if expression_reguliere_exemple_text.match?(Regexp.new(expression_reguliere, timeout: ExpressionReguliereValidator::TIMEOUT))

    self.errors.add(:expression_reguliere_exemple_text, I18n.t('errors.messages.mismatch_regexp'))
    true
  rescue Regexp::TimeoutError
    self.errors.add(:expression_reguliere, I18n.t('errors.messages.evil_regexp'))
    true
  rescue RegexpError
    self.errors.add(:expression_reguliere, I18n.t('errors.messages.syntax_error_regexp'))
    true
  end

  def typed_champ_value_for_export(champ, path = :value)
    Sanitizers::Xml.sanitize(champ_text_value(champ))
  end

  private

  def set_default_options
    if options&.empty?
      self.options = { formatted_mode: 'simple', letters_accepted: true, numbers_accepted: true, special_characters_accepted: true }
    end
  end
end
