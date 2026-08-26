# frozen_string_literal: true

class TypesDeChamp::PrefillFormatted < TypesDeChamp::Prefill
  def example_value
    case options["formatted_mode"].to_sym
    when :advanced
      options["expression_reguliere_exemple_text"]
    when :simple
      # Generate simple random example
      example = +""

      min, max = [options["min_character_length"].to_i, options["max_character_length"].to_i]

      # repeat until min
      example.size.upto(min) do
        example += generate_sequence(options)
      end

      # truncate to max or to a reasonable length
      max = 100 if max == 0 || max > 100
      example = example[..max - 1] if example.size > max

      example
    end
  end

  def generate_sequence(options)
    seq = +""
    seq += ("A".."Z").to_a.sample(3).join if string_to_bool(options["letters_accepted"])
    seq += ("0".."9").to_a.sample(2).join if string_to_bool(options["numbers_accepted"])
    seq += %w[! ? - . _].sample if string_to_bool(options["special_characters_accepted"])
    seq
  end

  def string_to_bool(str)
    ActiveModel::Type::Boolean.new.cast(str)
  end
end
