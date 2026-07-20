# frozen_string_literal: true

class TypesDeChamp::FormattedValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, types_de_champ)
    types_de_champ.to_a
      .flat_map { it.repetition? ? it.flat_children(procedure.draft_revision) : it }
      .filter(&:formatted?)
      .each do |tdc|
        validate_characters_rules(procedure, attribute, tdc)
        validate_character_length(procedure, attribute, tdc)
        validate_regexp(procedure, attribute, tdc)
      end
  end

  private

  def validate_characters_rules(procedure, attribute, tdc)
    if tdc.formatted_mode == 'simple' &&
        tdc.letters_accepted == '0' &&
        tdc.numbers_accepted == '0' &&
        tdc.special_characters_accepted == '0'
      # i18n-tasks-use t('errors.messages.invalid_character_rules')
      procedure.errors.add(
        attribute,
        :invalid_character_rules,
        type_de_champ: tdc
      )
    end
  end

  def validate_character_length(procedure, attribute, tdc)
    if tdc.formatted_mode == 'simple' &&
        tdc.max_character_length.present? &&
        tdc.min_character_length.present? &&
        (tdc.min_character_length.to_i > tdc.max_character_length.to_i)
      # i18n-tasks-use t('errors.messages.invalid_character_length')
      procedure.errors.add(
        attribute,
        :invalid_character_length,
        type_de_champ: tdc
      )
    end
  end

  def validate_regexp(procedure, attribute, tdc)
    if tdc.formatted_mode == 'advanced' && tdc.invalid_regexp?
      procedure.errors.add(
        attribute,
        procedure.errors.generate_message(attribute, :expression_reguliere_invalid, { value: tdc.libelle }),
        type_de_champ: tdc
      )
    end
  end
end
